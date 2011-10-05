require "test/unit"

require File.join(File.dirname(__FILE__),"keychain_manager.rb")

class KeychainManagerTest < Test::Unit::TestCase

  def setup
    # Do nothing
  end

  def teardown

  end

  def test_create_delete_exists
    kcm = KeychainManager.new("some_keychain")
    assert !kcm.exists?
    kcm.create
    assert kcm.exists?
    kcm.delete
    assert !kcm.exists?
  end

  def test_file
    kcm = KeychainManager.new("some_keychain")
    assert !kcm.exists?
    assert_nil kcm.file
    kcm.create
    assert_not_nil kcm.file
    kcm.delete
    assert !kcm.exists?
  end

  def test_generate_rsa_key
    rsa_tmp = '/tmp/test.rsa'
    File.delete(rsa_tmp) if File.exists?(rsa_tmp)
    KeychainManager.generate_rsa_key(rsa_tmp, 2048)
    assert File.exists?(rsa_tmp)
  end

  def test_generate_cert_request
    rsa_tmp = '/tmp/test.rsa'
    File.delete(rsa_tmp) if File.exists?(rsa_tmp)
    KeychainManager.generate_rsa_key(rsa_tmp, 2048)

    cert_tmp = '/tmp/test.cert'
    File.delete(cert_tmp) if File.exists?(cert_tmp)
    KeychainManager.generate_cert_request('partners@reflect7.com', 'Reflect7', 'US', rsa_tmp, cert_tmp)
    assert File.exists?(cert_tmp)
  end

  def test_import_rsa_key
    rsa_tmp = '/tmp/test.rsa'
    KeychainManager.generate_rsa_key(rsa_tmp, 2048)

    kcm = KeychainManager.new("some_keychain")
    kcm.create
    assert kcm.import_rsa_key(rsa_tmp).include?('1 key imported')
    kcm.delete
  end
end