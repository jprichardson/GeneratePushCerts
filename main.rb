require 'watir-webdriver'
#require 'watir-webdriver/extensions/wait'
require 'yaml'

config = YAML::load(File.open(Dir.pwd + '/config.yml'))

USER = config['user']
PASSWORD = config['password']
COMPANY = config['company']

RSA_FILE = '/tmp/push_notification.key'
CERT_REQUEST_FILE = '/tmp/CertificateSigningRequest.certSigningRequest'

def main
  puts("Let's get this party started.")

  generate_cert_request

  browser = Watir::Browser.new(:chrome)

  browser.goto("https://developer.apple.com/ios/manage/bundles/index.action")
  table = nil

  if browser.body.text.include?('Sign in')
    puts("Not logged in... logging in...")
    browser.text_field(name: 'theAccountName').set(USER)
    browser.text_field(id: 'accountpassword').set(PASSWORD)
    form = browser.form(name:'appleConnectForm')
    form.submit()
    puts("we're in!")
  end

  table  = browser.div(:class => 'nt_multi').table #table of Apple App Ids, now called AAID

  count = table.rows.count
  0.upto(count - 1) do |i|
    tds = table[i]
    if tds[0].strong.exists?
      unless tds[0].strong.attribute_value(:title).nil?
        aaid = tds[0].strong.attribute_value(:title).strip
        if aaid.ends_with?('FanFB')
          if tds[1].text.include?('Enabled for Production')
            puts "#{aaid} already enabled. Skipping..."
          elsif tds[1].text.include?('Configurable for Production')
            puts "Configuring certificate for #{aaid}..."
            tds[4].a.click #'Configure' link
            configure_cert(browser) #new configure page
            STDIN.gets
          end
        end
      end
    end

  end

  puts('Done. Press [ENTER] to exit.')
  STDIN.gets.strip

end

def configure_cert(browser)
  browser.checkbox(id: 'enablePush').click() #enable configure buttons
  browser.button(id: 'aps-assistant-btn-prod-en').click() #configure button
  Watir::Wait.until { browser.body.text.include?('Generate a Certificate Signing Request') }

  browser.button(id: 'ext-gen59').click() #on lightbox overlay, click continue
  browser.file_field(name: 'upload').set(CERT_REQUEST_FILE)
  browser.file_field(name: 'upload').click() #calls some local javascript to validate the file and enable continue button
  #browser.form(name: 'certsubmit').submit()
  browser.button(id: 'ext-gen75').click()

end

def generate_rsa_key
  puts 'Generating RSA key...'
  `openssl genrsa -out #{RSA_FILE} 2048`
end

def generate_cert_request
  generate_rsa_key
  puts 'Generating Certificate Request...'
  `openssl req -new -key #{RSA_FILE} -out #{CERT_REQUEST_FILE}  -subj "/#{USER}, CN=#{COMPANY}, C=US"`
end

class String

  def ends_with?(suffix)
    suffix = suffix.to_s
    self[-suffix.length..-1] == suffix
  end

end

main()