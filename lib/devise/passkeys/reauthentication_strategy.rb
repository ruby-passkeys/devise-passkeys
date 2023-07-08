# frozen_string_literal: true

require "devise/strategies/authenticatable"
require_relative "passkey_issuer"

module Devise
  module Strategies
    class PasskeyReauthentication < PasskeyAuthenticatable
      def authentication_challenge_key
        "#{mapping.singular}_current_reauthentication_challenge"
      end

      # Reauthentication runs through Authentication (user_set)
      # as part of its cycle, which would normally reset CSRF
      # data in the session
      def clean_up_csrf?
        false
      end
    end
  end
end

Warden::Strategies.add(:passkey_reauthentication, Devise::Strategies::PasskeyReauthentication)
