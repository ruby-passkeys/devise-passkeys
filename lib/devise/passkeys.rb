# frozen_string_literal: true

require "devise"
require "warden/webauthn"
require_relative "passkeys/rails"
require_relative "passkeys/model"
require_relative "passkeys/controllers"
require_relative "passkeys/passkey_issuer"
require_relative "passkeys/strategy"
require_relative "passkeys/reauthentication_strategy"
require_relative "passkeys/version"

module Devise
  # All Passkeys sub-modules, models, classes, concerns etc are inherited from here.
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
                  model: "devise/passkeys/model",
                  strategy: true,
                  no_input: true
