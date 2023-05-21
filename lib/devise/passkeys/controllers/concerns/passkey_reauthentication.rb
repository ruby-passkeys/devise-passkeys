# frozen_string_literal: true

module Devise
  module Passkeys
    module Controllers
      module Concerns
        # PasskeyReauthentication concern.
        module PasskeyReauthentication
          extend ActiveSupport::Concern

          def store_reauthentication_token_in_session
            session[passkey_reauthentication_token_key] = Devise.friendly_token(50)
          end

          def stored_reauthentication_token
            session[passkey_reauthentication_token_key]
          end

          def clear_reauthentication_token!
            session.delete(passkey_reauthentication_token_key)
          end

          def consume_reauthentication_token!
            value = stored_reauthentication_token
            clear_reauthentication_token!
            value
          end

          def valid_reauthentication_token?(given_reauthentication_token:)
            Devise.secure_compare(consume_reauthentication_token!, given_reauthentication_token)
          end

          def passkey_reauthentication_token_key
            "#{resource_name}_current_reauthentication_token"
          end
        end
      end
    end
  end
end
