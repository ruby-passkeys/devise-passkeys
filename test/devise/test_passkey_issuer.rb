# frozen_string_literal: true

require "test_helper"
require_relative "../test_helper/webauthn_test_helpers"

class Devise::TestPasskeyIssuer < ActiveSupport::TestCase
  include WebAuthnTestHelpers

  test "create_and_return_passkey" do
    user = User.create!(email: "test@test.com")

    relying_party = example_relying_party
    client = fake_client(origin: relying_party.origin)
    credential = create_raw_credential(credential_hash: client.create, relying_party: relying_party)

    passkey = Devise::Passkeys::PasskeyIssuer.build.create_and_return_passkey(resource: user, label: "Test Key",
                                                                              webauthn_credential: credential)
    assert_equal true, passkey.persisted?

    UserPasskey.find(passkey.id)

    user.passkeys.reload

    assert_equal user, passkey.user
    assert_equal "Test Key", passkey.label

    assert_equal credential.public_key, passkey.public_key
    assert_equal Base64.strict_encode64(credential.raw_id), passkey.external_id
    assert_equal credential.sign_count, passkey.sign_count
    assert_nil passkey.last_used_at
  end

  test "create_and_return_passkey with extra attributes" do
    user = User.create!(email: "test@test.com")

    relying_party = example_relying_party
    client = fake_client(origin: relying_party.origin)
    credential = create_raw_credential(credential_hash: client.create, relying_party: relying_party)

    registration_time = Time.current

    passkey = Devise::Passkeys::PasskeyIssuer.build.create_and_return_passkey(
      resource: user,
      label: "Test Key",
      webauthn_credential: credential,
      extra_attributes: { last_used_at: registration_time, sign_count: 234 }
    )
    assert_equal true, passkey.persisted?

    UserPasskey.find(passkey.id)

    user.passkeys.reload

    assert_equal user, passkey.user
    assert_equal "Test Key", passkey.label

    assert_equal credential.public_key, passkey.public_key
    assert_equal Base64.strict_encode64(credential.raw_id), passkey.external_id
    assert_equal 234, passkey.sign_count
    assert_equal registration_time, passkey.last_used_at
  end
end

class Devise::TestPasskeyCredentialFinder < ActiveSupport::TestCase
  test "find_with_credential_id" do
    finder = Devise::Passkeys::PasskeyIssuer::CredentialFinder.new(resource_class: User)

    user = User.create!(email: "test@test.com")

    encoded_credential_id_1 = Base64.strict_encode64(SecureRandom.random_bytes(32))
    encoded_credential_id_2 = Base64.strict_encode64(SecureRandom.random_bytes(32))

    passkey_1 = user.passkeys.create!(label: "dummy key", external_id: encoded_credential_id_1, public_key: "abbbcvcc")
    passkey_2 = user.passkeys.create!(label: "dummy key", external_id: encoded_credential_id_2, public_key: "abbbcvcc")

    assert_equal passkey_1, finder.find_with_credential_id(encoded_credential_id_1)
    assert_equal passkey_2, finder.find_with_credential_id(encoded_credential_id_2)
    assert_nil finder.find_with_credential_id(Base64.strict_encode64(SecureRandom.random_bytes(32)))
  end

  test "find_with_credential_id: no credentials" do
    finder = Devise::Passkeys::PasskeyIssuer::CredentialFinder.new(resource_class: User)

    assert_nil finder.find_with_credential_id(Base64.strict_encode64(SecureRandom.random_bytes(32)))
  end
end
