require 'devise/strategies/authenticatable'
require_relative 'passkey_issuer'

module Devise
  module Strategies
    class PasskeyReauthentication < PasskeyAuthenticatable
      def authentication_challenge_key
        "#{mapping.singular}_current_reauthentication_challenge"
      end
    end
  end
end

Warden::Strategies.add(:passkey_reauthentication, Devise::Strategies::PasskeyReauthentication)