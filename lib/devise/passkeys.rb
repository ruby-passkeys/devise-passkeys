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
  # This module provides a devise extension to use passkeys instead
  # of passwords for user authentication.
  #
  # It is lightweight and non-configurable. It does what it has to do and
  # leaves some manual implementation to you.
  #
  # Please consult the {file:README.md#label-Usage} for installation & configuration instructions;
  # and the links below for additional reading about:
  #
  # - What passkeys are
  # - The underlying gems used to build this devise extension
  # - Platform support & user interface implementation guides
  #
  # @see https://webauthn.guide
  # @see https://passkeys.dev
  # @see https://fidoalliance.org/passkeys
  # @see https://github.com/cedarcode/webauthn-ruby
  # @see https://github.com/ruby-passkeys/warden-webauthn
  module Passkeys
    # This is a helper method that creates and returns a passkey for
    # the given User (`resource`), using the provided label & `WebAuthn::Credential`
    # @see PasskeyIssuer#create_and_return_passkey
    # @return A saved passkey for the the given User (`resource`)
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
