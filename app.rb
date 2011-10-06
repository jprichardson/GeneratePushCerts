require 'watir-webdriver'
require 'fileutils'
require File.join(File.dirname(__FILE__), 'keychain_manager.rb')
require 'yaml'

config = YAML::load(File.open(Dir.pwd + '/config.yml'))

USER = config['user']
PASSWORD = config['password']
COMPANY = config['company']
KEYCHAIN = config['keychain']
DOWNLOAD_DIR = config['download_dir']
CERT_DIR = config['cert_dir']

APP_IDS_URL = "https://developer.apple.com/ios/manage/bundles/index.action"
RSA_FILE = '/tmp/push_notification.key'
CERT_REQUEST_FILE = '/tmp/CertificateSigningRequest.certSigningRequest'
DOWNLOADED_CERT_FILE = "#{DOWNLOAD_DIR}aps_production_identity.cer"
P12_FILE = '/tmp/out.p12'
PEM_FILE = '/tmp/out.pem'

WAIT_TO = 180 #3 mins

def main
  puts("Let's get this party started.")

  Dir.mkdir(CERT_DIR) unless Dir.exists?(CERT_DIR)

  KeychainManager.generate_rsa_key(RSA_FILE)
  KeychainManager.generate_cert_request(USER, COMPANY, 'US', RSA_FILE, CERT_REQUEST_FILE)

  browser = Watir::Browser.new(:chrome)
  browser.goto(APP_IDS_URL)

  table = nil
  if browser.body.text.include?('Sign in')
    puts("Not logged in... logging in...")
    browser.text_field(name: 'theAccountName').set(USER)
    browser.text_field(id: 'accountpassword').set(PASSWORD)
    form = browser.form(name:'appleConnectForm')
    form.submit()
    puts("Logged in!")
  end

  table  = browser.div(:class => 'nt_multi').table #table of Apple App Ids, now called AAID

  count = table.rows.count
  0.upto(count - 1) do |i|
    tds = table[i]
    if tds[0].strong.exists?
      name = tds[0].strong
      aaid = ''
      if name.text.strip.ends_with?('...') #can't see all of the name, must mouse over
        aaid = name.attribute_value(:title).strip
      else
        aaid = name.text.strip
      end

      if aaid.ends_with?('FanFB')
        if tds[1].text.include?('Enabled for Production')
          puts "#{aaid} already enabled. Skipping..."
        elsif tds[1].text.include?('Configurable for Production') #too be safe, generate new Keychain everytime
          puts "Configuring certificate for #{aaid}..."
          tds[4].a.click #'Configure' link
          configure_for_prod(browser, aaid) #new configure page
        end
      end
    end
  end

  puts('Done.')
  #STDIN.gets.strip

end

def configure_for_prod(browser, app)
  pem_file = CERT_DIR + app + '.pem'

  kcm = KeychainManager.new(KEYCHAIN)
  kcm.delete if kcm.exists? #start fresh
  kcm.create; puts "creating new keychain for #{app}"

  kcm.import_rsa_key(RSA_FILE); puts "importing RSA..."

  configure_cert(browser, app); puts "time for some browser fun..."

  kcm.import_apple_cert(DOWNLOADED_CERT_FILE); puts "importing Apple cert"
  File.delete(DOWNLOADED_CERT_FILE)
  kcm.export_identities(P12_FILE)
  KeychainManager.convert_p12_to_pem(P12_FILE, pem_file); puts "exporting #{pem_file}"

  kcm.delete
end

def configure_cert(browser, app)
  browser.checkbox(id: 'enablePush').click() #enable configure buttons
  browser.button(id: 'aps-assistant-btn-prod-en').click() #configure button

  Watir::Wait.until { browser.body.text.include?('Generate a Certificate Signing Request') }

  browser.button(id: 'ext-gen59').click() #on lightbox overlay, click continue

  Watir::Wait.until { browser.body.text.include?('Submit Certificate Signing Request') }

  browser.file_field(name: 'upload').set(CERT_REQUEST_FILE)
  browser.execute_script("callFileValidate();")
  #browser.file_field(name: 'upload').click() #calls some local javascript to validate the file and enable continue button, unfortunately File Browse dialog shows up

  browser.button(id: 'ext-gen75').click()

  Watir::Wait.until(WAIT_TO) { browser.body.text.include?('Your APNs SSL Certificate has been generated.') }

  browser.button(id: 'ext-gen59').click() #continue

  Watir::Wait.until { browser.body.text.include?('Step 1: Download') }

  File.delete(DOWNLOADED_CERT_FILE) if File.exists?(DOWNLOADED_CERT_FILE)

  browser.button(alt: 'Download').click() #download cert

  puts('Checking for existence of downloaded certificate file...')
  while !File.exists?(DOWNLOADED_CERT_FILE)
    sleep 1
  end

  Watir::Wait.until { browser.body.text.include?("Download & Install Your Apple Push Notification service SSL Certificate") }

  browser.button(id: 'ext-gen91').click()
  browser.goto(APP_IDS_URL)
end

def convert_p12_to_pem(app)
  puts "Converting p12 to pem for #{app}"
  `openssl pkcs12 -nodes -in #{P12_FILE} -out #{CERT_DIR}#{app}.pem`
end

def export_identity(app)
  puts "Exporting Identity for #{app}..."
  `security export -k #{KEYCHAIN_FILE} -t identities -f pkcs12 -P "" -o #{P12_FILE}`
end

def generate_rsa_key
  puts 'Generating RSA key...'
  `openssl genrsa -out #{RSA_FILE} 2048`
end

def generate_cert_request
  generate_rsa_key
  import_rsa_key
  puts 'Generating Certificate Request...'
  `openssl req -new -key #{RSA_FILE} -out #{CERT_REQUEST_FILE}  -subj "/#{USER}, CN=#{COMPANY}, C=US"`
end

def import_rsa_key
  puts 'Importing RSA key...'
  `security import #{RSA_FILE} -k #{KEYCHAIN_FILE}`
end

def import_apple_cert(app)
  puts "Error: File Not Found: #{DOWNLOADED_CERT_FILE}" unless File.exists?(DOWNLOADED_CERT_FILE)
  puts "Importing Apple Cert for #{app}..."
  `security import #{DOWNLOADED_CERT_FILE} -k #{KEYCHAIN_FILE}`
end

class String
  def ends_with?(suffix)
    suffix = suffix.to_s
    self[-suffix.length..-1] == suffix
  end
end

main()