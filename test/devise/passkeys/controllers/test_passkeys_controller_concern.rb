# frozen_string_literal: true

require "test_helper"
require_relative "../../../test_helper/webauthn_test_helpers"
require_relative "../../../test_helper/extra_assertions"

class Devise::Passkeys::Controllers::TestPasskeysControllerConcern < ActionDispatch::IntegrationTest
  include WebAuthnTestHelpers
  include ExtraAssertions
  include Devise::Test::IntegrationHelpers

  class TestPasskeyController < DeviseController
    include Devise::Passkeys::Controllers::PasskeysControllerConcern

    attr_accessor :resource

    def relying_party
      WebAuthn::RelyingParty.new(origin: "https://www.example.com")
    end

    def resource_name
      :user
    end

    def root_path
      "/"
    end

    # Dummy action to setup reauthentication token
    def reauthenticate
      store_reauthentication_token_in_session
      render json: { token: stored_reauthentication_token }
    end
  end

  setup do
    Rails.application.routes.draw do
      devise_scope :user do
        post "/passkey/reauthenticate" => "devise/passkeys/controllers/test_passkeys_controller_concern/test_passkey#reauthenticate"

        post "/passkey/new_create_challenge" => "devise/passkeys/controllers/test_passkeys_controller_concern/test_passkey#new_create_challenge"
        post "/passkey/create" => "devise/passkeys/controllers/test_passkeys_controller_concern/test_passkey#create"

        post "/passkey/:id/new_destroy_challenge" => "devise/passkeys/controllers/test_passkeys_controller_concern/test_passkey#new_destroy_challenge"

        delete "/passkey/:id" => "devise/passkeys/controllers/test_passkeys_controller_concern/test_passkey#destroy"
      end
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "#new_create_challenge: not signed in" do
    post "/passkey/new_create_challenge"
    assert_redirected_to "http://www.example.com/"
  end

  test "#new_create_challenge: signed in" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    passkey = user.passkeys.create!(
      label: "dummy",
      external_id: Base64.strict_encode64(credential.id),
      public_key: Base64.strict_encode64(credential.public_key)
    )

    excluded_credentials = [{ "type" => "public-key", "id" => passkey.external_id }]

    sign_in(user)

    post "/passkey/new_create_challenge"

    response_json = JSON.parse(response.body)

    assert_equal response_json["challenge"], session["user_passkey_creation_challenge"]
    assert_equal 120_000, response_json["timeout"]
    assert_equal ({}), response_json["extensions"]
    assert_equal excluded_credentials, response_json["excludeCredentials"]
    assert_equal ({ "residentKey" => "required", "userVerification" => "required" }), response_json["authenticatorSelection"]
  end

  test "#create: creates a passkey for the user" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    3.times do |n|
      user.passkeys.create!(label: n.to_s, external_id: "dummy-passkey-#{n}",
                            public_key: Base64.strict_encode64(SecureRandom.random_bytes(10)))
    end

    excluded_credentials = user.passkeys.pluck(:external_id).map do |id|
      { "type" => "public-key", "id" => id }
    end

    sign_in(user)

    post "/passkey/reauthenticate"
    refute_nil session["user_current_reauthentication_token"]
    token = response.parsed_body["token"]

    post "/passkey/new_create_challenge"

    response_json = JSON.parse(response.body)

    assert_equal response_json["challenge"], session["user_passkey_creation_challenge"]
    assert_equal 120_000, response_json["timeout"]
    assert_equal ({}), response_json["extensions"]
    assert_equal excluded_credentials, response_json["excludeCredentials"]
    assert_equal ({ "residentKey" => "required", "userVerification" => "required" }), response_json["authenticatorSelection"]

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

    assert_no_difference "User.count" do
      assert_difference "user.passkeys.count", +1 do
        post "/passkey/create",
             params: { passkey: { label: "Test", credential: raw_credential.to_json, reauthentication_token: token } }

        assert_redirected_to "http://www.example.com/"
      end
    end

    passkey = user.passkeys.last

    assert_equal "Test", passkey.label
    assert_equal Base64.strict_encode64(response.credential.id), passkey.external_id
    refute_nil passkey.public_key
    assert_nil passkey.last_used_at

    assert_nil session["user_passkey_creation_challenge"]
    assert_nil session["user_current_reauthentication_token"]
  end

  test "#create: user not verified" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    3.times do |n|
      user.passkeys.create!(label: n.to_s, external_id: "dummy-passkey-#{n}",
                            public_key: Base64.strict_encode64(SecureRandom.random_bytes(10)))
    end

    excluded_credentials = user.passkeys.pluck(:external_id).map do |id|
      { "type" => "public-key", "id" => id }
    end

    sign_in(user)

    post "/passkey/reauthenticate"
    refute_nil session["user_current_reauthentication_token"]
    token = response.parsed_body["token"]

    post "/passkey/new_create_challenge"

    response_json = JSON.parse(response.body)

    assert_equal response_json["challenge"], session["user_passkey_creation_challenge"]
    assert_equal 120_000, response_json["timeout"]
    assert_equal ({}), response_json["extensions"]
    assert_equal excluded_credentials, response_json["excludeCredentials"]
    assert_equal ({ "residentKey" => "required", "userVerification" => "required" }), response_json["authenticatorSelection"]

    raw_credential = client.create(challenge: response_json["challenge"], user_verified: false)

    assert_no_difference "User.count" do
      assert_no_difference "user.passkeys.count" do
        post "/passkey/create",
             params: { passkey: { label: "Test", credential: raw_credential.to_json, reauthentication_token: token } }

        assert_response :bad_request
        assert_translation_missing_message(translation_key: "en.devise.test_passkey.user.webauthn_user_verified_verification_error")
      end
    end

    assert_nil session["user_passkey_creation_challenge"]
    refute_nil session["user_current_reauthentication_token"]
  end

  test "#create: bad challenge" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    3.times do |n|
      user.passkeys.create!(label: n.to_s, external_id: "dummy-passkey-#{n}",
                            public_key: Base64.strict_encode64(SecureRandom.random_bytes(10)))
    end

    excluded_credentials = user.passkeys.pluck(:external_id).map do |id|
      { "type" => "public-key", "id" => id }
    end

    sign_in(user)

    post "/passkey/reauthenticate"
    refute_nil session["user_current_reauthentication_token"]
    token = response.parsed_body["token"]

    post "/passkey/new_create_challenge"

    response_json = JSON.parse(response.body)

    assert_equal response_json["challenge"], session["user_passkey_creation_challenge"]
    assert_equal 120_000, response_json["timeout"]
    assert_equal ({}), response_json["extensions"]
    assert_equal excluded_credentials, response_json["excludeCredentials"]
    assert_equal ({ "residentKey" => "required", "userVerification" => "required" }), response_json["authenticatorSelection"]

    raw_credential = client.create(challenge: "blah", user_verified: true)

    assert_no_difference "User.count" do
      assert_no_difference "user.passkeys.count" do
        post "/passkey/create",
             params: { passkey: { label: "Test", credential: raw_credential.to_json, reauthentication_token: token } }

        assert_response :bad_request
        assert_translation_missing_message(translation_key: "en.devise.test_passkey.user.webauthn_challenge_verification_error")
      end
    end

    assert_nil session["user_passkey_creation_challenge"]
    refute_nil session["user_current_reauthentication_token"]
  end

  test "#create: credential cannot be parsed" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    3.times do |n|
      user.passkeys.create!(label: n.to_s, external_id: "dummy-passkey-#{n}",
                            public_key: Base64.strict_encode64(SecureRandom.random_bytes(10)))
    end

    excluded_credentials = user.passkeys.pluck(:external_id).map do |id|
      { "type" => "public-key", "id" => id }
    end

    sign_in(user)

    post "/passkey/reauthenticate"
    refute_nil session["user_current_reauthentication_token"]
    token = response.parsed_body["token"]

    post "/passkey/new_create_challenge"

    response_json = JSON.parse(response.body)

    assert_no_difference "User.count" do
      assert_no_difference "user.passkeys.count" do
        post "/passkey/create",
             params: { passkey: { label: "Test", credential: "blahj", reauthentication_token: token } }

        assert_response :bad_request
        assert_translation_missing_message(translation_key: "en.devise.test_passkey.user.credential_missing_or_could_not_be_parsed")
      end
    end

    assert_nil session["user_passkey_creation_challenge"]
    refute_nil session["user_current_reauthentication_token"]
  end

  test "#create: credential missing" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    3.times do |n|
      user.passkeys.create!(label: n.to_s, external_id: "dummy-passkey-#{n}",
                            public_key: Base64.strict_encode64(SecureRandom.random_bytes(10)))
    end

    excluded_credentials = user.passkeys.pluck(:external_id).map do |id|
      { "type" => "public-key", "id" => id }
    end

    sign_in(user)

    post "/passkey/reauthenticate"
    refute_nil session["user_current_reauthentication_token"]
    token = response.parsed_body["token"]

    post "/passkey/new_create_challenge"

    response_json = JSON.parse(response.body)

    assert_no_difference "User.count" do
      assert_no_difference "user.passkeys.count" do
        post "/passkey/create", params: { passkey: { label: "Test", reauthentication_token: token } }

        assert_response :bad_request
        assert_translation_missing_message(translation_key: "en.devise.test_passkey.user.credential_missing_or_could_not_be_parsed")
      end
    end

    assert_nil session["user_passkey_creation_challenge"]
    refute_nil session["user_current_reauthentication_token"]
  end

  test "#create: never reauthenticated" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    3.times do |n|
      user.passkeys.create!(label: n.to_s, external_id: "dummy-passkey-#{n}",
                            public_key: Base64.strict_encode64(SecureRandom.random_bytes(10)))
    end

    excluded_credentials = user.passkeys.pluck(:external_id).map do |id|
      { "type" => "public-key", "id" => id }
    end

    sign_in(user)

    post "/passkey/new_create_challenge"

    response_json = JSON.parse(response.body)

    assert_equal response_json["challenge"], session["user_passkey_creation_challenge"]
    assert_equal 120_000, response_json["timeout"]
    assert_equal ({}), response_json["extensions"]
    assert_equal excluded_credentials, response_json["excludeCredentials"]
    assert_equal ({ "residentKey" => "required", "userVerification" => "required" }), response_json["authenticatorSelection"]

    raw_credential = client.create(challenge: response_json["challenge"], user_verified: true)

    assert_no_difference "User.count" do
      assert_no_difference "user.passkeys.count" do
        post "/passkey/create",
             params: { passkey: { label: "Test", credential: raw_credential.to_json, reauthentication_token: :blah } }

        assert_response :bad_request
        assert_translation_missing_error(translation_key: "en.devise.test_passkey.user.not_reauthenticated")
      end
    end
  end

  test "#create: passkey label missing" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    3.times do |n|
      user.passkeys.create!(label: n.to_s, external_id: "dummy-passkey-#{n}",
                            public_key: Base64.strict_encode64(SecureRandom.random_bytes(10)))
    end

    excluded_credentials = user.passkeys.pluck(:external_id).map do |id|
      { "type" => "public-key", "id" => id }
    end

    sign_in(user)

    post "/passkey/reauthenticate"
    refute_nil session["user_current_reauthentication_token"]
    token = response.parsed_body["token"]

    post "/passkey/new_create_challenge"

    response_json = JSON.parse(response.body)

    assert_equal response_json["challenge"], session["user_passkey_creation_challenge"]
    assert_equal 120_000, response_json["timeout"]
    assert_equal ({}), response_json["extensions"]
    assert_equal excluded_credentials, response_json["excludeCredentials"]
    assert_equal ({ "residentKey" => "required", "userVerification" => "required" }), response_json["authenticatorSelection"]

    raw_credential = client.create(challenge: response_json["challenge"], user_verified: true)

    assert_no_difference "User.count" do
      assert_no_difference "user.passkeys.count" do
        assert_raises ActiveRecord::RecordInvalid do
          post "/passkey/create",
               params: { passkey: { label: "", credential: raw_credential.to_json, reauthentication_token: token } }
        end
      end
    end

    refute_nil session["user_passkey_creation_challenge"]
    refute_nil session["user_current_reauthentication_token"]
  end

  test "#new_destroy_challenge: not signed in" do
    post "/passkey/1234/new_destroy_challenge"
    assert_redirected_to "http://www.example.com/"
  end

  test "#new_destroy_challenge: only 1 passkey" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    passkey = user.passkeys.create!(
      label: "dummy",
      external_id: Base64.strict_encode64(credential.id),
      public_key: Base64.strict_encode64(credential.public_key)
    )

    excluded_credentials = [{ "type" => "public-key", "id" => passkey.external_id }]

    sign_in(user)

    post "/passkey/#{passkey.id}/new_destroy_challenge"
    assert_response :bad_request
    assert_translation_missing_error(translation_key: "en.devise.test_passkey.user.must_be_at_least_one_passkey")
  end

  test "#new_destroy_challenge: other user passkey" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    3.times do |n|
      user.passkeys.create!(label: n.to_s, external_id: "dummy-passkey-#{n}",
                            public_key: Base64.strict_encode64(SecureRandom.random_bytes(10)))
    end

    other_user = User.create!(email: "example@example.com")

    passkey = other_user.passkeys.create!(
      label: "dummy",
      external_id: Base64.strict_encode64(credential.id),
      public_key: Base64.strict_encode64(credential.public_key)
    )

    excluded_credentials = [{ "type" => "public-key", "id" => passkey.external_id }]

    sign_in(user)

    post "/passkey/#{passkey.id}/new_destroy_challenge"
    assert_response :not_found
  end

  test "#new_destroy_challenge: signed in, multiple passkeys" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    old_passkey = user.passkeys.create!(label: "OLD", external_id: "dummy-passkey",
                                        public_key: Base64.strict_encode64(SecureRandom.random_bytes(10)))

    passkey = user.passkeys.create!(
      label: "dummy",
      external_id: Base64.strict_encode64(credential.id),
      public_key: Base64.strict_encode64(credential.public_key)
    )

    allowed_credentials = [{ "type" => "public-key", "id" => passkey.external_id }]

    sign_in(user)

    post "/passkey/#{old_passkey.id}/new_destroy_challenge"
    assert_response :ok

    refute_nil session["user_current_reauthentication_challenge"]

    response_json = JSON.parse(response.body)

    assert_equal response_json["challenge"], session["user_current_reauthentication_challenge"]
    assert_equal 120_000, response_json["timeout"]
    assert_equal ({}), response_json["extensions"]
    assert_equal allowed_credentials, response_json["allowCredentials"]
    assert_equal "required", response_json["userVerification"]
  end

  test "#destroy: not signed in" do
    assert_no_difference "UserPasskey.count" do
      delete "/passkey/1234"
    end
    assert_redirected_to "http://www.example.com/"
  end

  test "#destroy: only 1 passkey" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    passkey = user.passkeys.create!(
      label: "dummy",
      external_id: Base64.strict_encode64(credential.id),
      public_key: Base64.strict_encode64(credential.public_key)
    )

    excluded_credentials = [{ "type" => "public-key", "id" => passkey.external_id }]

    sign_in(user)

    assert_no_difference "UserPasskey.count" do
      delete "/passkey/#{passkey.id}"
    end
    assert_response :bad_request
    assert_translation_missing_error(translation_key: "en.devise.test_passkey.user.must_be_at_least_one_passkey")
  end

  test "#destroy: other user passkey" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    3.times do |n|
      user.passkeys.create!(label: n.to_s, external_id: "dummy-passkey-#{n}",
                            public_key: Base64.strict_encode64(SecureRandom.random_bytes(10)))
    end

    other_user = User.create!(email: "example@example.com")

    passkey = other_user.passkeys.create!(
      label: "dummy",
      external_id: Base64.strict_encode64(credential.id),
      public_key: Base64.strict_encode64(credential.public_key)
    )

    excluded_credentials = [{ "type" => "public-key", "id" => passkey.external_id }]

    sign_in(user)

    assert_no_difference "UserPasskey.count" do
      delete "/passkey/#{passkey.id}"
    end
    assert_response :not_found
  end

  test "#destroy: success with reauthentication_token" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    old_passkey = user.passkeys.create!(label: "OLD", external_id: "dummy-passkey",
                                        public_key: Base64.strict_encode64(SecureRandom.random_bytes(10)))

    passkey = user.passkeys.create!(
      label: "dummy",
      external_id: Base64.strict_encode64(credential.id),
      public_key: Base64.strict_encode64(credential.public_key)
    )

    allowed_credentials = [{ "type" => "public-key", "id" => passkey.external_id }]

    sign_in(user)

    post "/passkey/reauthenticate"
    refute_nil session["user_current_reauthentication_token"]
    token = response.parsed_body["token"]

    assert_difference "UserPasskey.count", -1 do
      delete "/passkey/#{passkey.id}", params: { passkey: { reauthentication_token: token } }

      assert_redirected_to "http://www.example.com/"
    end

    assert_nil UserPasskey.find_by(id: passkey.id)
  end

  test "#destroy: never reauthenticated" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    old_passkey = user.passkeys.create!(label: "OLD", external_id: "dummy-passkey",
                                        public_key: Base64.strict_encode64(SecureRandom.random_bytes(10)))

    passkey = user.passkeys.create!(
      label: "dummy",
      external_id: Base64.strict_encode64(credential.id),
      public_key: Base64.strict_encode64(credential.public_key)
    )

    allowed_credentials = [{ "type" => "public-key", "id" => passkey.external_id }]

    sign_in(user)

    assert_no_difference "UserPasskey.count" do
      delete "/passkey/#{passkey.id}", params: { passkey: { reauthentication_token: "blah" } }

      assert_response :bad_request
      assert_translation_missing_error(translation_key: "en.devise.test_passkey.user.not_reauthenticated")
    end

    assert_equal passkey, UserPasskey.find_by(id: passkey.id)
  end

  test "#destroy: failure without reauthentication_token" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    old_passkey = user.passkeys.create!(label: "OLD", external_id: "dummy-passkey",
                                        public_key: Base64.strict_encode64(SecureRandom.random_bytes(10)))

    passkey = user.passkeys.create!(
      label: "dummy",
      external_id: Base64.strict_encode64(credential.id),
      public_key: Base64.strict_encode64(credential.public_key)
    )

    allowed_credentials = [{ "type" => "public-key", "id" => passkey.external_id }]

    sign_in(user)

    post "/passkey/reauthenticate"
    refute_nil session["user_current_reauthentication_token"]
    token = response.parsed_body["token"]

    assert_no_difference "UserPasskey.count" do
      delete "/passkey/#{passkey.id}", params: { passkey: { value: "blah" } }

      assert_response :bad_request
      assert_translation_missing_error(translation_key: "en.devise.test_passkey.user.not_reauthenticated")
    end

    assert_equal passkey, UserPasskey.find_by(id: passkey.id)
  end

  test "#destroy: failure with bad reauthentication_token" do
    relying_party = example_relying_party(options: { origin: "www.example.com" })
    client = fake_client(origin: "https://www.example.com")
    credential = create_credential(client: client, relying_party: relying_party)

    user = User.create!(email: "test@test.com")

    old_passkey = user.passkeys.create!(label: "OLD", external_id: "dummy-passkey",
                                        public_key: Base64.strict_encode64(SecureRandom.random_bytes(10)))

    passkey = user.passkeys.create!(
      label: "dummy",
      external_id: Base64.strict_encode64(credential.id),
      public_key: Base64.strict_encode64(credential.public_key)
    )

    allowed_credentials = [{ "type" => "public-key", "id" => passkey.external_id }]

    sign_in(user)

    post "/passkey/reauthenticate"
    refute_nil session["user_current_reauthentication_token"]
    token = response.parsed_body["token"]

    assert_no_difference "UserPasskey.count" do
      delete "/passkey/#{passkey.id}", params: { passkey: { reauthentication_token: "asdasdsadasd" } }

      assert_response :bad_request
      assert_translation_missing_error(translation_key: "en.devise.test_passkey.user.not_reauthenticated")
    end

    assert_equal passkey, UserPasskey.find_by(id: passkey.id)
  end
end
