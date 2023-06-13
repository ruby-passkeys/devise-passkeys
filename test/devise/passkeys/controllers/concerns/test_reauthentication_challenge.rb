# frozen_string_literal: true

require "test_helper"

class Devise::Passkeys::Controllers::Concerns::TestReauthenticationChallenge < ActiveSupport::TestCase
  class TestClass
    include Devise::Passkeys::Controllers::Concerns::ReauthenticationChallenge

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

  test "#store_reauthentication_challenge_in_session" do
    options_for_authentication = OpenStruct.new(challenge: SecureRandom.random_bytes(50))
    assert_nil @test_class.session["test_value:1234_current_reauthentication_challenge"]

    token = @test_class.store_reauthentication_challenge_in_session(options_for_authentication: options_for_authentication)
    refute_nil token

    assert_equal token, @test_class.session["test_value:1234_current_reauthentication_challenge"]
  end

  test "#Reauthentication_challenge_session_key" do
    assert_equal "test_value:1234_current_reauthentication_challenge",
                 @test_class.Reauthentication_challenge_session_key
  end
end

class Devise::Passkeys::Controllers::Concerns::TestReauthenticationChallengeCustomization < ActiveSupport::TestCase
  class TestClass
    include Devise::Passkeys::Controllers::Concerns::ReauthenticationChallenge

    attr_accessor :session

    def initialize
      self.session = {}
    end

    def Reauthentication_challenge_session_key
      "passkey_reauth_challenge"
    end
  end

  setup do
    @test_class = TestClass.new
  end

  test "#store_reauthentication_challenge_in_session" do
    options_for_authentication = OpenStruct.new(challenge: SecureRandom.random_bytes(50))
    assert_nil @test_class.session["passkey_reauth_challenge"]

    token = @test_class.store_reauthentication_challenge_in_session(options_for_authentication: options_for_authentication)
    refute_nil token

    assert_equal token, @test_class.session["passkey_reauth_challenge"]
  end

  test "#Reauthentication_challenge_session_key" do
    assert_equal "passkey_reauth_challenge", @test_class.Reauthentication_challenge_session_key
  end
end
