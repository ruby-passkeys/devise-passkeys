# frozen_string_literal: true

require "test_helper"
require_relative "../../../test_helper/webauthn_test_helpers"

class Devise::Passkeys::Controllers::TestSessionsControllerConcern < ActionDispatch::IntegrationTest
  include WebAuthnTestHelpers

  class TestSessionController < ActionController::Base
    include Devise::Passkeys::Controllers::SessionsControllerConcern

    def relying_party
      WebAuthn::RelyingParty.new(origin: "test.host")
    end

    def resource_name
      :user
    end
  end

  setup do
    Rails.application.routes.draw do
      post "/session/new_challenge" => "devise/passkeys/controllers/test_sessions_controller_concern/test_session#new_challenge"
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "#new_challenge" do
    post "/session/new_challenge"

    response_json = JSON.parse(response.body)

    assert_equal response_json["challenge"], session["user_current_webauthn_authentication_challenge"]
    assert_equal 120_000, response_json["timeout"]
    assert_equal ({}), response_json["extensions"]
    assert_empty response_json["allowCredentials"]
    assert_equal "required", response_json["userVerification"]
  end
end

class Devise::Passkeys::Controllers::TestSessionsControllerConcernCustomization < ActionDispatch::IntegrationTest
  include WebAuthnTestHelpers

  class TestSessionController < ActionController::Base
    include Devise::Passkeys::Controllers::SessionsControllerConcern

    def relying_party
      WebAuthn::RelyingParty.new(origin: "test.host")
    end

    def resource_name
      "user"
    end

    def authentication_challenge_key
      "passkey_challenge"
    end
  end

  setup do
    Rails.application.routes.draw do
      post "/session/new_challenge" => "devise/passkeys/controllers/test_sessions_controller_concern_customization/test_session#new_challenge"
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "#new_challenge" do
    post "/session/new_challenge"

    response_json = JSON.parse(response.body)

    assert_equal response_json["challenge"], session["passkey_challenge"]
    assert_equal 120_000, response_json["timeout"]
    assert_equal ({}), response_json["extensions"]
    assert_empty response_json["allowCredentials"]
    assert_equal "required", response_json["userVerification"]
  end
end

class Devise::Passkeys::Controllers::TestSessionsControllerConcernSetup < ActionDispatch::IntegrationTest
  include WebAuthnTestHelpers

  class TestSessionController < ActionController::Base
    include Devise::Passkeys::Controllers::SessionsControllerConcern

    def resource_name
      "user"
    end
  end

  setup do
    Rails.application.routes.draw do
      post "/session/new_challenge" => "devise/passkeys/controllers/test_sessions_controller_concern_setup/test_session#new_challenge"
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "#new_challenge: raises RuntimeError if set_relying_party_in_request_env has not been implemented" do
    assert_raises RuntimeError do
      post "/session/new_challenge"
    end
  end
end
