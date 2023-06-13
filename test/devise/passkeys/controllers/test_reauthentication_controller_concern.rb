# frozen_string_literal: true

require "test_helper"
require_relative "../../../test_helper/webauthn_test_helpers"
require_relative "../../../test_helper/extra_assertions"

class Devise::Passkeys::Controllers::TestReauthenticationControllerConcern < ActionDispatch::IntegrationTest
  include WebAuthnTestHelpers
  include ExtraAssertions
  include Devise::Test::IntegrationHelpers

  class TestReauthenticationController < ActionController::Base
    include Devise::Passkeys::Controllers::ReauthenticationControllerConcern

    attr_accessor :resource

    def relying_party
      WebAuthn::RelyingParty.new(origin: "https://www.example.com")
    end

    def set_relying_party_in_request_env
      request.env[relying_party_key] = relying_party
    end

    def resource_name
      :user
    end

    def root_path
      "/home"
    end
  end

  setup do
    Rails.application.routes.draw do
      post "/reauthentication/new_challenge" => "devise/passkeys/controllers/test_reauthentication_controller_concern/test_reauthentication#new_challenge"
      post "/reauthentication/reauthenticate" => "devise/passkeys/controllers/test_reauthentication_controller_concern/test_reauthentication#reauthenticate"
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "#new_challenge: not signed in" do
    post "/reauthentication/new_challenge"
    assert_redirected_to "http://www.example.com/"
  end

  test "#new_challenge" do
    user = User.create!(email: "test@test.com")

    3.times do |n|
      user.passkeys.create!(label: n.to_s, external_id: "dummy-passkey-#{n}",
                            public_key: Base64.strict_encode64(SecureRandom.random_bytes(10)))
    end

    allowed_passkey_ids = user.passkeys.pluck(:external_id).map do |id|
      { "type" => "public-key", "id" => id }
    end

    sign_in(user)
    post "/reauthentication/new_challenge"

    response_json = JSON.parse(response.body)

    assert_equal response_json["challenge"], session["user_current_reauthentication_challenge"]
    assert_equal 120_000, response_json["timeout"]
    assert_equal ({}), response_json["extensions"]
    assert_equal allowed_passkey_ids, response_json["allowCredentials"]
    assert_equal "required", response_json["userVerification"]
  end

  test "#reauthenticate: success" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    passkey = user.passkeys.create!(
      label: "dummy",
      external_id: Base64.strict_encode64(credential.id),
      public_key: Base64.strict_encode64(credential.public_key)
    )

    sign_in(user)

    post "/reauthentication/new_challenge"

    assert_equal JSON.parse(response.body)["challenge"], session["user_current_reauthentication_challenge"]

    assertion = assertion_from_client(client: client, challenge: JSON.parse(response.body)["challenge"],
                                      user_verified: true)

    post "/reauthentication/reauthenticate", params: { passkey_credential: assertion.to_json }, as: :json

    response_json = JSON.parse(response.body)

    assert_equal ({ "reauthentication_token" => session["user_current_reauthentication_token"] }), response_json
    assert_nil session["user_current_reauthentication_challenge"]
  end

  test "#reauthenticate: user not verified" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    passkey = user.passkeys.create!(
      label: "dummy",
      external_id: Base64.strict_encode64(credential.id),
      public_key: Base64.strict_encode64(credential.public_key)
    )

    sign_in(user)

    post "/reauthentication/new_challenge"

    assert_equal JSON.parse(response.body)["challenge"], session["user_current_reauthentication_challenge"]

    assertion = assertion_from_client(client: client, challenge: JSON.parse(response.body)["challenge"],
                                      user_verified: false)

    post "/reauthentication/reauthenticate", params: { passkey_credential: assertion.to_json }, as: :json

    response_json = JSON.parse(response.body)

    assert_translation_missing_error(translation_key: "en.devise.failure.user.webauthn_user_verified_verification_error")
    assert_nil session["user_current_reauthentication_challenge"]
    assert_response :unauthorized
  end

  test "#reauthenticate: bad challenge" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    passkey = user.passkeys.create!(
      label: "dummy",
      external_id: Base64.strict_encode64(credential.id),
      public_key: Base64.strict_encode64(credential.public_key)
    )

    sign_in(user)

    post "/reauthentication/new_challenge"

    assert_equal JSON.parse(response.body)["challenge"], session["user_current_reauthentication_challenge"]

    assertion = assertion_from_client(client: client, challenge: "blah", user_verified: true)

    post "/reauthentication/reauthenticate", params: { passkey_credential: assertion.to_json }, as: :json

    response_json = JSON.parse(response.body)

    assert_translation_missing_error(translation_key: "en.devise.failure.user.webauthn_challenge_verification_error")
    assert_nil session["user_current_reauthentication_challenge"]
    assert_response :unauthorized
  end

  test "#reauthenticate: credential removed" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    passkey = user.passkeys.create!(
      label: "dummy",
      external_id: Base64.strict_encode64(credential.id),
      public_key: Base64.strict_encode64(credential.public_key)
    )

    sign_in(user)

    post "/reauthentication/new_challenge"

    assert_equal JSON.parse(response.body)["challenge"], session["user_current_reauthentication_challenge"]

    assertion = assertion_from_client(client: client, challenge: "blah", user_verified: true)

    passkey.destroy

    post "/reauthentication/reauthenticate", params: { passkey_credential: assertion.to_json }, as: :json

    response_json = JSON.parse(response.body)

    assert_translation_missing_error(translation_key: "en.devise.failure.user.stored_credential_not_found")
    assert_nil session["user_current_reauthentication_challenge"]
    assert_response :unauthorized
  end

  test "#reauthenticate: credential cannot be parsed" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    passkey = user.passkeys.create!(
      label: "dummy",
      external_id: Base64.strict_encode64(credential.id),
      public_key: Base64.strict_encode64(credential.public_key)
    )

    sign_in(user)

    post "/reauthentication/new_challenge"

    assert_equal JSON.parse(response.body)["challenge"], session["user_current_reauthentication_challenge"]

    assertion = assertion_from_client(client: client, challenge: "blah", user_verified: true)

    passkey.destroy

    post "/reauthentication/reauthenticate", params: { passkey_credential: "blah" }, as: :json

    response_json = JSON.parse(response.body)

    assert_equal ({ "error" => "You need to sign in or sign up before continuing." }), response.parsed_body
    assert_nil session["user_current_reauthentication_challenge"]
    assert_response :unauthorized
  end

  test "#reauthenticate: credential missing" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    passkey = user.passkeys.create!(
      label: "dummy",
      external_id: Base64.strict_encode64(credential.id),
      public_key: Base64.strict_encode64(credential.public_key)
    )

    sign_in(user)

    post "/reauthentication/new_challenge"

    assert_equal JSON.parse(response.body)["challenge"], session["user_current_reauthentication_challenge"]

    assertion = assertion_from_client(client: client, challenge: "blah", user_verified: true)

    passkey.destroy

    post "/reauthentication/reauthenticate", params: { other: 1234 }, as: :json

    response_json = JSON.parse(response.body)

    assert_equal ({ "error" => "You need to sign in or sign up before continuing." }), response.parsed_body
    assert_nil session["user_current_reauthentication_challenge"]
    assert_response :unauthorized
  end

  test "#reauthenticate: not signed in" do
    relying_party = example_relying_party(options: { origin: "test.host" })
    client = fake_client
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    passkey = user.passkeys.create!(
      label: "dummy",
      external_id: Base64.strict_encode64(credential.id),
      public_key: Base64.strict_encode64(credential.public_key)
    )

    sign_in(user)
    post "/reauthentication/new_challenge"

    assert_equal JSON.parse(response.body)["challenge"], session["user_current_reauthentication_challenge"]

    assertion = assertion_from_client(client: client, challenge: JSON.parse(response.body)["challenge"],
                                      user_verified: true)

    sign_out(user)

    post "/reauthentication/reauthenticate", params: { passkey_credential: assertion.to_json }, as: :json
    assert_equal ({ "error" => "You need to sign in or sign up before continuing." }), response.parsed_body
    assert_response :unauthorized
  end
end

class Devise::Passkeys::Controllers::TestReauthenticationControllerConcernSetup < ActionDispatch::IntegrationTest
  include WebAuthnTestHelpers
  include Devise::Test::IntegrationHelpers

  class TestReauthenticationController < ActionController::Base
    include Devise::Passkeys::Controllers::ReauthenticationControllerConcern

    attr_accessor :resource

    def resource_name
      :user
    end

    def root_path
      "/home"
    end
  end

  setup do
    Rails.application.routes.draw do
      post "/reauthentication/new_challenge" => "devise/passkeys/controllers/test_reauthentication_controller_concern_setup/test_reauthentication#new_challenge"
      post "/reauthentication/reauthenticate" => "devise/passkeys/controllers/test_reauthentication_controller_concern_setup/test_reauthentication#reauthenticate"
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "#new_challenge: raises RuntimeError if set_relying_party_in_request_env has not been implemented" do
    user = User.create!(email: "test@test.com")
    sign_in(user)
    assert_raises RuntimeError do
      post "/reauthentication/new_challenge"
    end
  end
end
