# frozen_string_literal: true

require "test_helper"

class Devise::Passkeys::Controllers::Concerns::TestPasskeyReauthentication < ActiveSupport::TestCase
  class TestClass
    include Devise::Passkeys::Controllers::Concerns::PasskeyReauthentication

    attr_accessor :session

    def initialize
      self.session = {}
    end

    def resource_name
      "test_value:1234"
    end
  end

  setup do
    @test_class = TestClass.new
  end

  test "#store_reauthentication_token_in_session" do
    assert_nil @test_class.session["test_value:1234_current_reauthentication_token"]

    token = @test_class.store_reauthentication_token_in_session
    refute_nil token

    assert_equal token, @test_class.session["test_value:1234_current_reauthentication_token"]
  end

  test "#stored_reauthentication_token" do
    token = "test123123"

    assert_nil @test_class.stored_reauthentication_token
    @test_class.session["test_value:1234_current_reauthentication_token"] = token
    assert_equal token, @test_class.stored_reauthentication_token
  end

  test "#clear_reauthentication_token!" do
    token = "test123123"
    @test_class.session["test_value:1234_current_reauthentication_token"] = token

    @test_class.clear_reauthentication_token!

    assert_nil @test_class.session["test_value:1234_current_reauthentication_token"]
  end

  test "#consume_reauthentication_token!" do
    token = "test123123"
    @test_class.session["test_value:1234_current_reauthentication_token"] = token

    assert_equal token, @test_class.consume_reauthentication_token!

    assert_nil @test_class.session["test_value:1234_current_reauthentication_token"]
  end

  test "#valid_reauthentication_token?: consumes token on comparison" do
    token = "test123123"
    @test_class.session["test_value:1234_current_reauthentication_token"] = token

    assert_equal true, @test_class.valid_reauthentication_token?(given_reauthentication_token: token)
    assert_nil @test_class.session["test_value:1234_current_reauthentication_token"]

    token = "oeuifjhweoirjweoirj"
    @test_class.session["test_value:1234_current_reauthentication_token"] = token
    assert_equal false, @test_class.valid_reauthentication_token?(given_reauthentication_token: "blah")
    assert_nil @test_class.session["test_value:1234_current_reauthentication_token"]
  end

  test "#passkey_reauthentication_token_key" do
    assert_equal "test_value:1234_current_reauthentication_token", @test_class.passkey_reauthentication_token_key
  end
end

class Devise::Passkeys::Controllers::Concerns::TestPasskeyReauthenticationCustomization < ActiveSupport::TestCase
  class TestClass
    include Devise::Passkeys::Controllers::Concerns::PasskeyReauthentication

    attr_accessor :session

    def initialize
      self.session = {}
    end

    def passkey_reauthentication_token_key
      "passkey_reauth"
    end
  end

  setup do
    @test_class = TestClass.new
  end

  test "#store_reauthentication_token_in_session" do
    assert_nil @test_class.session["passkey_reauth"]

    token = @test_class.store_reauthentication_token_in_session
    refute_nil token

    assert_equal token, @test_class.session["passkey_reauth"]
  end

  test "#stored_reauthentication_token" do
    token = "test123123"

    assert_nil @test_class.stored_reauthentication_token
    @test_class.session["passkey_reauth"] = token
    assert_equal token, @test_class.stored_reauthentication_token
  end

  test "#clear_reauthentication_token!" do
    token = "test123123"
    @test_class.session["passkey_reauth"] = token

    @test_class.clear_reauthentication_token!

    assert_nil @test_class.session["passkey_reauth"]
  end

  test "#consume_reauthentication_token!" do
    token = "test123123"
    @test_class.session["passkey_reauth"] = token

    assert_equal token, @test_class.consume_reauthentication_token!

    assert_nil @test_class.session["passkey_reauth"]
  end

  test "#valid_reauthentication_token?: consumes token on comparison" do
    token = "test123123"
    @test_class.session["passkey_reauth"] = token

    assert_equal true, @test_class.valid_reauthentication_token?(given_reauthentication_token: token)
    assert_nil @test_class.session["passkey_reauth"]

    token = "oeuifjhweoirjweoirj"
    @test_class.session["passkey_reauth"] = token
    assert_equal false, @test_class.valid_reauthentication_token?(given_reauthentication_token: "blah")
    assert_nil @test_class.session["passkey_reauth"]
  end

  test "#passkey_reauthentication_token_key" do
    assert_equal "passkey_reauth", @test_class.passkey_reauthentication_token_key
  end
end