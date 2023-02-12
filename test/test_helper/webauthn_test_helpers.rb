require "webauthn/fake_client"

module WebAuthnTestHelpers
  def example_relying_party(options: {})
    return WebAuthn::RelyingParty.new(**{
      origin: "https://example.test",
      name: "Example Relying Party"
    }.merge(options))
  end

  def fake_client(origin: "https://example.test")
    return WebAuthn::FakeClient.new(origin)
  end

  def generate_raw_challenge
    SecureRandom.random_bytes(32)
  end

  def encode_challenge(raw_challenge: generate_raw_challenge)
    Base64.strict_encode64(raw_challenge)
  end

  def assertion_from_client(client:, challenge:, user_verified: true)
    client.get(challenge: challenge, user_verified: user_verified)
  end

  def assertion_response(assertion:)
    WebAuthn::AuthenticatorAssertionResponse.new(
      client_data_json: assertion["response"]["clientDataJSON"],
      authenticator_data: assertion["response"]["authenticatorData"],
      signature: assertion["response"]["signature"]
    )
  end

  def create_credential(client:, rp_id: nil, relying_party:)
    rp_id ||= relying_party.id || URI.parse(client.origin).host

    create_result = client.create(rp_id: rp_id)

    attestation_object =
      if client.encoding
        relying_party.encoder.decode(create_result["response"]["attestationObject"])
      else
        create_result["response"]["attestationObject"]
      end

    client_data_json =
      if client.encoding
        relying_party.encoder.decode(create_result["response"]["clientDataJSON"])
      else
        create_result["response"]["clientDataJSON"]
      end

    response = WebAuthn::AuthenticatorAttestationResponse.new(
      attestation_object: attestation_object,
      client_data_json: client_data_json,
      relying_party: relying_party
    )

    return response.credential
  end
end