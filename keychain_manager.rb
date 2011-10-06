#Mac OS X Keychain Manager Gem.
#Copyright: JP Richardson 2011
#email: jprichardson@gmail.com
#MIT Licensed

class KeychainManager
  attr_reader :name

  CMD_KC = 'security'
  CMD_SSL = 'openssl'
  @file = nil

  def initialize(name)
    @name = name
  end

  def create
    `#{CMD_KC} create-keychain -p "" #{@name}`
  end

  def delete
    `#{CMD_KC} delete-keychain #{self.file}`
  end

  def exist?
    exists?
  end

  def exists?
    `#{CMD_KC} list-keychains`.include?(@name)
  end

  def export_identities(p12_file)
    `#{CMD_KC} export -k #{self.file} -t identities -f pkcs12 -P '' -o #{p12_file}`
  end

  def file
    return @file unless @file.nil?
    KeychainManager.keychain_files.each do |f|
      if f.include?(@name)
        @file = f
        break
      end
    end
    @file
  end

  def import_apple_cert(apple_cert_file)
    `#{CMD_KC} import #{apple_cert_file} -k #{self.file}`
  end

  def import_rsa_key(rsa_file)
    `#{CMD_KC} import #{rsa_file} -P "" -k #{self.file}`
  end

########### CLASS Methods

  def self.convert_p12_to_pem(p12_file, pem_file)
    #`expect -c "spawn #{CMD_SSL} pkcs12 -nodes -in #{p12_file} -out #{pem_file}; expect -re \\\"Enter Import Password:\\\"; send \\\"\\n\\\"; expect eof"`
    `#{CMD_SSL} pkcs12 -passin pass: -nodes -in #{p12_file} -out #{pem_file}`
  end

  def self.generate_cert_request(email, company, country, rsa_file, cert_file)
    `#{CMD_SSL} req -new -key #{rsa_file} -out #{cert_file}  -subj "/#{email}, CN=#{company}, C=#{country}"`
  end

  def self.generate_rsa_key(rsa_file, keysize=2048)
    `#{CMD_SSL} genrsa -out #{rsa_file} #{keysize}`
  end

  def self.keychain_files
    files = []
    `#{CMD_KC} list-keychains`.split("\n").each do |file|
      files << file.strip.gsub('"', '')
    end
    files
  end

end