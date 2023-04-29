# frozen_string_literal: true

require "test_helper"
require_relative "../test_helper/webauthn_test_helpers"

class Devise::TestPasskeys < ActiveSupport::TestCase
  include WebAuthnTestHelpers
  test "has version number" do
    refute_nil ::Devise::Passkeys::VERSION
  end

  test "create_and_return_passkey" do
    user = User.create!(email: "test@test.com")

    relying_party = example_relying_party
    client = fake_client(origin: relying_party.origin)
    credential = create_raw_credential(credential_hash: client.create, relying_party: relying_party)

    passkey = Devise::Passkeys.create_and_return_passkey(resource: user, label: "Test Key", webauthn_credential: credential)
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

    passkey = Devise::Passkeys.create_and_return_passkey(
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
