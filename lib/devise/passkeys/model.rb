# frozen_string_literal: true

module Devise
  module Models
    # This is the actual module that gets included in your
    # model when you include `:passkey_authenticatable` in the
    # `devise` call (eg: `devise :passkey_authenticatable, ...`).
    #
    # For more thorough steps on setting up the model please follow link below.
    # @see README 
    module PasskeyAuthenticatable
      # This is a callback that is called right after a successful passkey authentication.
      #
      # *Important*: Must follow the steps in the README documentation to fully set up a model
      # and use passkeys.  
      #
      # By default, it is a no-op, but you can override it in your model for any custom behavior
      # (such as notifying the user of a new login).
      # @param passkey [String] the passkey that was used for authentication
      def after_passkey_authentication(passkey:); end
    end
  end
end
