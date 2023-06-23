# frozen_string_literal: true

module Devise
  module Passkeys
    module Controllers
      module Concerns
        # This concern is responsible for storing, retrieving, clearing, consuming,
        # and validating the reauthentication token in the session.
        module Reauthentication
          extend ActiveSupport::Concern

          # This method is responsible for storing the reauthentication token.
          #
          # @return [String] the reauthentication token
          def store_reauthentication_token_in_session
            session[passkey_reauthentication_token_key] = Devise.friendly_token(50)
          end

          # This method is responsible for retrieving the reauthentication token.
          #
          # @return [String] the reauthentication token
          def stored_reauthentication_token
            session[passkey_reauthentication_token_key]
          end

          # This method is responsible for clearing the reauthentication token.
          #
          # @return [String] the reauthentication token
          def clear_reauthentication_token!
            session.delete(passkey_reauthentication_token_key)
          end

          # This method is responsible for consuming(i.e. retrieve & clear) the reauthentication token.
          #
          # @return [String] the reauthentication token
          def consume_reauthentication_token!
            value = stored_reauthentication_token
            clear_reauthentication_token!
            value
          end

          # This method is responsible for validating the reauthentication token.
          # Note, it will consume the stored token.
          #
          # @param [String] given_reauthentication_token token to compare store token against
          def valid_reauthentication_token?(given_reauthentication_token:)
            Devise.secure_compare(consume_reauthentication_token!, given_reauthentication_token)
          end

          # This method is responsible for generating the reauthentication token session key.
          #
          # @return [String] the reauthentication token session key
          def passkey_reauthentication_token_key
            "#{resource_name}_current_reauthentication_token"
          end
        end
      end
    end
  end
end
