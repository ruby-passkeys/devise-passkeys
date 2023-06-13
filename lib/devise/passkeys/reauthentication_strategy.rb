# frozen_string_literal: true

require "devise/strategies/authenticatable"
require_relative "passkey_issuer"

module Devise
  module Strategies
    class Reauthentication < PasskeyAuthenticatable
      def authentication_challenge_key
        "#{mapping.singular}_current_reauthentication_challenge"
      end
    end
  end
end

Warden::Strategies.add(:Reauthentication, Devise::Strategies::Reauthentication)
