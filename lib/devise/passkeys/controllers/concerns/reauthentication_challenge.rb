# frozen_string_literal: true

module Devise
  module Passkeys
    module Controllers
      module Concerns
        # This concern is responsible for storing the reauthentication challenge in the session.
        module ReauthenticationChallenge
          extend ActiveSupport::Concern

          # This method is responsible for generating the reauthentication challenge session key.
          #
          # @return [String] the reauthentication challenge session key
          def passkey_reauthentication_challenge_session_key
            "#{resource_name}_current_reauthentication_challenge"
          end

          # This method is responsible for storing the reauthentication challenge in the session.
          #
          # @param [WebAuthn::PublicKeyCredential::RequestOptions] options_for_authentication the options for authentication
          # @return [String] the reauthentication challenge
          def store_reauthentication_challenge_in_session(options_for_authentication:)
            session[passkey_reauthentication_challenge_session_key] = options_for_authentication.challenge
          end
        end
      end
    end
  end
end
