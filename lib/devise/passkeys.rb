# frozen_string_literal: true

require 'devise'
require_relative "passkeys/version"

module Devise
  module Passkeys
    def self.create_and_return_passkey(resource:, label:, webauthn_credential:, extra_attributes: {})
      PasskeyIssuer.build.create_and_return_passkey(
        resource: resource,
        label: label,
        webauthn_credential: webauthn_credential,
        extra_attributes: extra_attributes
      )
    end
  end
end

Devise.add_module :passkey_authenticatable,
                  model: 'devise/passkeys/model',
                  strategy: true,
                  no_input: true