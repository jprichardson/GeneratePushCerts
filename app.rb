require 'watir-webdriver'
require 'fileutils'
require 'keychain_manager'
require 'yaml'

config = YAML::load(File.open(Dir.pwd + '/config.yml'))

USER = config['user']
PASSWORD = config['password']
KEYCHAIN = config['keychain']
DOWNLOAD_DIR = config['download_dir']
CERT_DIR = config['cert_dir']

APP_IDS_URL = "https://developer.apple.com/ios/manage/bundles/index.action"
RSA_FILE = '/tmp/push_notification.key'
CERT_REQUEST_FILE = '/tmp/CertificateSigningRequest.certSigningRequest'
DOWNLOADED_CERT_FILE = "#{DOWNLOAD_DIR}aps_production_identity.cer"
P12_FILE = '/tmp/out.p12'
PEM_FILE = '/tmp/out.pem'

END_WITH = 'FanFB' #You may want to modify this and this line: if aaid.end_with?(END_WITH) (currently right around line 60)

WAIT_TO = 180 #3 mins

def main
  puts("Let's get this party started.")

  Dir.mkdir(CERT_DIR) unless Dir.exists?(CERT_DIR)

  KeychainManager.generate_rsa_key(RSA_FILE)
  KeychainManager.generate_cert_request(USER, 'US', RSA_FILE, CERT_REQUEST_FILE)

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
      if name.text.strip.end_with?('...') #can't see all of the name, must mouse over
        aaid = name.attribute_value(:title).strip
      else
        aaid = name.text.strip
      end

      if aaid.end_with?(END_WITH)
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
  kcm.create; #puts "creating new keychain for #{app}"

  kcm.import_rsa_key(RSA_FILE); #puts "importing RSA..."

  configure_cert(browser, app); #puts "time for some browser fun..."

  kcm.import_apple_cert(DOWNLOADED_CERT_FILE); #puts "importing Apple cert"
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

main()