require 'watir-webdriver'
require 'yaml'

config = YAML::load(File.open(Dir.pwd + '/config.yml'))

USER = config['user']
PASSWORD = config['password']

browser = Watir::Browser.new(:chrome)

browser.goto("https://developer.apple.com/ios/manage/bundles/index.action")
table = nil

if browser.body.text.include?('Sign in')
  puts("Not logged in... logging in...")
  browser.text_field(name: 'theAccountName').set(USER)
  browser.text_field(id: 'accountpassword').set(PASSWORD)
  form = browser.form(name:'appleConnectForm')
  form.submit()
  puts("we're in!'")
end

table  = browser.div(:class => 'nt_multi').table #table of Apple App Ids, now called AAID

#puts table.html

count = table.rows.count
0.upto(count - 1) do |i|
  td = table[i][0]
  puts td
  #puts table[i][0].strong.html
end



puts('Done. Press [ENTER] to exit.')
STDIN.gets.strip