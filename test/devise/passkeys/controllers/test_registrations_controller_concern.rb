# frozen_string_literal: true

require "test_helper"
require_relative '../../../test_helper/webauthn_test_helpers'

class Devise::Passkeys::Controllers::TestRegistrationsControllerConcern < ActionDispatch::IntegrationTest
  include WebAuthnTestHelpers
  include Devise::Test::IntegrationHelpers

  class TestRegistrationController < Devise::RegistrationsController
    include Devise::Passkeys::Controllers::RegistrationsControllerConcern

    def relying_party
      WebAuthn::RelyingParty.new(origin: "https://www.example.com")
    end

    def set_relying_party_in_request_env
      request.env[relying_party_key] = relying_party
    end

    # Dummy action to setup reauthentication token
    def reauthenticate
      store_reauthentication_token_in_session
      render json: {token: stored_reauthentication_token}
    end

    def resource_name
      :user
    end
  end

  setup do
    Rails.application.routes.draw do
      devise_scope :user do
        post '/registration/new_challenge' => "devise/passkeys/controllers/test_registrations_controller_concern/test_registration#new_challenge"
        post '/registration' => "devise/passkeys/controllers/test_registrations_controller_concern/test_registration#create"
        post '/registration/reauthenticate' => "devise/passkeys/controllers/test_registrations_controller_concern/test_registration#reauthenticate"
        patch '/registration' => "devise/passkeys/controllers/test_registrations_controller_concern/test_registration#update"
        delete '/registration' => "devise/passkeys/controllers/test_registrations_controller_concern/test_registration#destroy"
      end
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "#new_challenge: signed in" do
    user = User.create!(email: "test@test.com")
    sign_in(user)

    post "/registration/new_challenge"
    assert_redirected_to "http://www.example.com/"
  end

  test "#new_challenge: not signed in" do
    post "/registration/new_challenge", params: {user: {email: "test@test.com", passkey_label: "Test"}}

    response_json = JSON.parse(response.body)
    assert_response :ok

    refute_nil session["user_current_webauthn_registration_challenge"]
    refute_nil session["user_current_webauthn_user_id"]

    assert_equal response_json["challenge"], session["user_current_webauthn_registration_challenge"]

    assert_equal ({
      "name" => "test@test.com",
      "id" => session["user_current_webauthn_user_id"],
      "displayName" => "test@test.com",
    }), response_json["user"]

    assert_equal 120_000, response_json["timeout"]
    assert_equal ({}), response_json["extensions"]
    assert_empty response_json["excludeCredentials"]
    assert_equal ({"userVerification" => "required"}), response_json["authenticatorSelection"]
  end

  test "#create: success" do
    relying_party = example_relying_party(options: {origin: "www.example.com"})
    client = fake_client(origin: "https://www.example.com")

    post "/registration/new_challenge", params: {user: {email: "test@test.com", passkey_label: "Test"}}

    webauthn_id = session["user_current_webauthn_user_id"]

    response_json = JSON.parse(response.body)
    assert_response :ok

    raw_credential = client.create(challenge: response_json["challenge"], user_verified: true)

    attestation_object =
      if client.encoding
        relying_party.encoder.decode(raw_credential["response"]["attestationObject"])
      else
        raw_credential["response"]["attestationObject"]
      end

    client_data_json =
      if client.encoding
        relying_party.encoder.decode(raw_credential["response"]["clientDataJSON"])
      else
        raw_credential["response"]["clientDataJSON"]
      end

    response = WebAuthn::AuthenticatorAttestationResponse.new(
      attestation_object: attestation_object,
      client_data_json: client_data_json,
      relying_party: relying_party
    )

    assert_difference "User.count", +1 do
    assert_difference "UserPasskey.count", +1 do
      post "/registration", params: {user: {email: "test@test.com", passkey_label: "Test", passkey_credential: raw_credential.to_json}}

      assert_redirected_to "http://www.example.com/"
    end
    end

    user = User.last
    passkey = user.passkeys.first

    assert_equal webauthn_id, user.webauthn_id
    assert_equal "test@test.com", user.email

    assert_equal "Test", passkey.label
    assert_equal Base64.strict_encode64(response.credential.id), passkey.external_id
    refute_nil passkey.public_key
    refute_nil passkey.last_used_at

    assert_nil session["user_current_webauthn_registration_challenge"]
    assert_nil session["user_current_webauthn_user_id"]
  end

  test "#create: user not verified" do
    relying_party = example_relying_party(options: {origin: "www.example.com"})
    client = fake_client(origin: "https://www.example.com")

    post "/registration/new_challenge", params: {user: {email: "test@test.com", passkey_label: "Test"}}

    webauthn_id = session["user_current_webauthn_user_id"]

    response_json = JSON.parse(response.body)
    assert_response :ok

    raw_credential = client.create(challenge: response_json["challenge"], user_verified: false)

    assert_no_difference "User.count" do
    assert_no_difference "UserPasskey.count" do
      post "/registration", params: {user: {email: "test@test.com", passkey_label: "Test", passkey_credential: raw_credential.to_json}}

      assert_response :bad_request
      assert_equal ({"message" => "translation missing: en.devise.registrations.user.webauthn_user_verified_verification_error"}), response.parsed_body
    end
    end
  end

  test "#create: bad challenge" do
    relying_party = example_relying_party(options: {origin: "www.example.com"})
    client = fake_client(origin: "https://www.example.com")

    post "/registration/new_challenge", params: {user: {email: "test@test.com", passkey_label: "Test"}}

    webauthn_id = session["user_current_webauthn_user_id"]

    response_json = JSON.parse(response.body)
    assert_response :ok

    raw_credential = client.create(challenge: "blah", user_verified: true)

    assert_no_difference "User.count" do
    assert_no_difference "UserPasskey.count" do
      post "/registration", params: {user: {email: "test@test.com", passkey_label: "Test", passkey_credential: raw_credential.to_json}}

      assert_response :bad_request
      assert_equal ({"message" => "translation missing: en.devise.registrations.user.webauthn_challenge_verification_error"}), response.parsed_body
    end
    end
  end

  test "#create: credential cannot be parsed" do
    relying_party = example_relying_party(options: {origin: "www.example.com"})
    client = fake_client(origin: "https://www.example.com")

    post "/registration/new_challenge", params: {user: {email: "test@test.com", passkey_label: "Test"}}

    webauthn_id = session["user_current_webauthn_user_id"]

    response_json = JSON.parse(response.body)
    assert_response :ok

    assert_no_difference "User.count" do
    assert_no_difference "UserPasskey.count" do
    assert_raises JSON::ParserError do
      post "/registration", params: {user: {email: "test@test.com", passkey_label: "Test", passkey_credential: "blah"}}
    end
    end
    end
  end

  test "#create: credential missing" do
    relying_party = example_relying_party(options: {origin: "www.example.com"})
    client = fake_client(origin: "https://www.example.com")

    post "/registration/new_challenge", params: {user: {email: "test@test.com", passkey_label: "Test"}}

    webauthn_id = session["user_current_webauthn_user_id"]

    response_json = JSON.parse(response.body)
    assert_response :ok

    assert_no_difference "User.count" do
    assert_no_difference "UserPasskey.count" do
    assert_raises TypeError do
      post "/registration", params: {user: {email: "test@test.com", passkey_label: "Test"}}
    end
    end
    end
  end

  test "#create: passkey label missing" do
    relying_party = example_relying_party(options: {origin: "www.example.com"})
    client = fake_client(origin: "https://www.example.com")

    post "/registration/new_challenge", params: {user: {email: "test@test.com", passkey_label: "Test"}}

    webauthn_id = session["user_current_webauthn_user_id"]

    response_json = JSON.parse(response.body)
    assert_response :ok

    raw_credential = client.create(challenge: response_json["challenge"], user_verified: false)

    assert_no_difference "User.count" do
    assert_no_difference "UserPasskey.count" do
      post "/registration", params: {user: { email: "test@test.com", passkey_credential: raw_credential.to_json}}

      assert_response :bad_request
      assert_equal ({"message" => "translation missing: en.devise.registrations.user.passkey_label_missing"}), response.parsed_body
    end
    end
  end

  test "#create: non-passkey attribute missing" do
    relying_party = example_relying_party(options: {origin: "www.example.com"})
    client = fake_client(origin: "https://www.example.com")

    post "/registration/new_challenge", params: {user: {email: "test@test.com", passkey_label: "Test"}}

    webauthn_id = session["user_current_webauthn_user_id"]

    response_json = JSON.parse(response.body)
    assert_response :ok

    raw_credential = client.create(challenge: response_json["challenge"], user_verified: false)

    assert_no_difference "User.count" do
    assert_no_difference "UserPasskey.count" do
      post "/registration", params: {user: {passkey_label: "Test", passkey_credential: raw_credential.to_json}}

      assert_response :bad_request
      assert_equal ({"message" => "translation missing: en.devise.registrations.user.email_missing"}), response.parsed_body
    end
    end
  end

  test "#create: did not complete challenge" do
    relying_party = example_relying_party(options: {origin: "www.example.com"})
    client = fake_client(origin: "https://www.example.com")

    raw_credential = client.create(challenge: encode_challenge, user_verified: false)

    assert_no_difference "User.count" do
    assert_no_difference "UserPasskey.count" do
    assert_raises NoMethodError do
      post "/registration", params: {user: { email: "test@test.com", passkey_label: "Test", passkey_credential: raw_credential.to_json}}
    end
    end
    end
  end

  test "#update: success with reauthentication_token" do
    user = User.create!(email: "test@test.com")
    sign_in(user)

    post '/registration/reauthenticate'
    refute_nil session["user_current_reauthentication_token"]
    token = response.parsed_body["token"]

    assert_no_difference "User.count" do
    assert_no_difference "UserPasskey.count" do
      patch "/registration", params: {user: {email: "hello@example.com", reauthentication_token: token}}
    end
    end

    assert_redirected_to "http://www.example.com/"

    assert_equal "hello@example.com", user.reload.email

    assert_nil session["user_current_reauthentication_token"]
  end

  test "#update: never reauthenticated" do
    user = User.create!(email: "test@test.com")
    sign_in(user)

    assert_no_difference "User.count" do
    assert_no_difference "UserPasskey.count" do
      patch "/registration", params: {user: {email: "hello@example.com", reauthentication_token: "asdasdasdasd"}}
    end
    end

    assert_response :bad_request
    assert_equal ({"error" => "translation missing: en.devise.registrations.user.not_reauthenticated"}), response.parsed_body

    assert_equal "test@test.com", user.reload.email

    assert_nil session["user_current_reauthentication_token"]
  end

  test "#update: failure without reauthentication_token" do
    user = User.create!(email: "test@test.com")
    sign_in(user)

    post '/registration/reauthenticate'
    refute_nil session["user_current_reauthentication_token"]
    token = response.parsed_body["token"]

    assert_no_difference "User.count" do
    assert_no_difference "UserPasskey.count" do
      patch "/registration", params: {user: {email: "hello@example.com"}}
    end
    end

    assert_response :bad_request
    assert_equal ({"error" => "translation missing: en.devise.registrations.user.not_reauthenticated"}), response.parsed_body

    assert_equal "test@test.com", user.reload.email

    assert_nil session["user_current_reauthentication_token"]
  end

  test "#update: failure with bad reauthentication_token" do
    user = User.create!(email: "test@test.com")
    sign_in(user)

    post '/registration/reauthenticate'
    refute_nil session["user_current_reauthentication_token"]
    token = response.parsed_body["token"]

    assert_no_difference "User.count" do
    assert_no_difference "UserPasskey.count" do
      patch "/registration", params: {user: {email: "hello@example.com", reauthentication_token: "blah"}}
    end
    end

    assert_response :bad_request
    assert_equal ({"error" => "translation missing: en.devise.registrations.user.not_reauthenticated"}), response.parsed_body

    assert_equal "test@test.com", user.reload.email

    assert_nil session["user_current_reauthentication_token"]
  end

  test "#destroy: success with reauthentication_token" do
    user = User.create!(email: "test@test.com")
    sign_in(user)

    user.passkeys.create!(label: "dummy", external_id: "dummy-passkey", public_key: Base64.strict_encode64(SecureRandom.random_bytes(10)))

    post '/registration/reauthenticate'
    refute_nil session["user_current_reauthentication_token"]
    token = response.parsed_body["token"]

    assert_difference "User.count", -1 do
    assert_difference "UserPasskey.count", -1 do
      delete "/registration", params: {user: {reauthentication_token: token}}
    end
    end

    assert_redirected_to "http://www.example.com/"

    assert_nil User.find_by(id: user.id)

    assert_nil session["user_current_reauthentication_token"]
  end

  test "#destroy: never reauthenticated" do
    user = User.create!(email: "test@test.com")
    sign_in(user)

    assert_no_difference "User.count" do
    assert_no_difference "UserPasskey.count" do
      delete "/registration", params: {user: { reauthentication_token: "asdasdasdasd"}}
    end
    end

    assert_response :bad_request
    assert_equal ({"error" => "translation missing: en.devise.registrations.user.not_reauthenticated"}), response.parsed_body

    assert_equal "test@test.com", user.reload.email

    assert_nil session["user_current_reauthentication_token"]
  end

  test "#destroy: failure without reauthentication_token" do
    user = User.create!(email: "test@test.com")
    sign_in(user)

    post '/registration/reauthenticate'
    refute_nil session["user_current_reauthentication_token"]
    token = response.parsed_body["token"]

    assert_no_difference "User.count" do
    assert_no_difference "UserPasskey.count" do
      delete "/registration", params: {user: {test: 123}}
    end
    end

    assert_response :bad_request
    assert_equal ({"error" => "translation missing: en.devise.registrations.user.not_reauthenticated"}), response.parsed_body

    assert_equal "test@test.com", user.reload.email

    assert_nil session["user_current_reauthentication_token"]
  end

  test "#destroy: failure with bad reauthentication_token" do
    user = User.create!(email: "test@test.com")
    sign_in(user)

    post '/registration/reauthenticate'
    refute_nil session["user_current_reauthentication_token"]
    token = response.parsed_body["token"]

    assert_no_difference "User.count" do
    assert_no_difference "UserPasskey.count" do
      delete "/registration", params: {user: {reauthentication_token: "blah"}}
    end
    end

    assert_response :bad_request
    assert_equal ({"error" => "translation missing: en.devise.registrations.user.not_reauthenticated"}), response.parsed_body

    assert_equal "test@test.com", user.reload.email

    assert_nil session["user_current_reauthentication_token"]
  end
end