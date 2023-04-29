# frozen_string_literal: true

module Devise
  module Passkeys
    module Controllers
      module Concerns
        module ReauthenticationChallenge
          extend ActiveSupport::Concern

          def passkey_reauthentication_challenge_session_key
            "#{resource_name}_current_reauthentication_challenge"
          end

          def store_reauthentication_challenge_in_session(options_for_authentication:)
            session[passkey_reauthentication_challenge_session_key] = options_for_authentication.challenge
          end
        end
      end
    end
  end
end