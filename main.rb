require 'watir-webdriver'
require 'yaml'

config = YAML::load(File.open(Dir.pwd + '/config.yml'))

USER = config['user']
PASSWORD = config['password']

def main
  puts("Let's get this party started.'")
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
            
          end
        end
      end
    end

  end

  puts('Done. Press [ENTER] to exit.')
  STDIN.gets.strip

end

def configure_cert(browser)
  
end

class String

  def ends_with?(suffix)
    suffix = suffix.to_s
    self[-suffix.length..-1] == suffix
  end

end

main()