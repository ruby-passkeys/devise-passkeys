# frozen_string_literal: true

module Devise
  module Models
    # This is the actual module that gets included in your
    # model when you write `devise :passkey_authenticatable`
    module PasskeyAuthenticatable
      # This is a callback called right after a successful passkey authentication
      def after_passkey_authentication; end
    end
  end
end
