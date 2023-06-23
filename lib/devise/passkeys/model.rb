# frozen_string_literal: true

module Devise
  module Models
    # This is the actual module that gets included in your
    # model when you include `:passkey_authenticatable` in the
    # `devise` call (eg: `devise :passkey_authenticatable, ...`).
    module PasskeyAuthenticatable
      # This is a callback that is called right after a successful passkey authentication.
      #
      # By default, it is a no-op, but you can override it in your model for any custom behavior (such as notifying users of a new login).
      def after_passkey_authentication; end
    end
  end
end
