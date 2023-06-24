# frozen_string_literal: true

module Devise
  module Passkeys
    module Controllers
      module Concerns
        # This concern is responsible for storing, retrieving, clearing, consuming,
        # and validating the reauthentication token in the session.
        #
        # A reauthentication token is a one-time random value that is used to
        # indicate that the user has successfully been reauthenticated. This can be
        # used for scenarios such as:
        #
        # - Adding a new passkey
        # - Deleting a passkey
        # - Performing sensitive actions inside your application
        #
        # You can customize which reauthentication token you're using by changing
        # the `passkey_reauthentication_token_key` method after including this concern
        module Reauthentication
          extend ActiveSupport::Concern

          # This method is responsible for storing the reauthentication token
          # in the session.
          #
          # The reauthentication token is securely generated using `Devise.friendly_token`
          #
          # @return [String] the reauthentication token
          # @see passkey_reauthentication_token_key
          def store_reauthentication_token_in_session
            session[passkey_reauthentication_token_key] = Devise.friendly_token(50)
          end

          # This method is responsible for retrieving the reauthentication token
          # from the session.
          #
          # @return [String] the reauthentication token
          # @see passkey_reauthentication_token_key
          # @see store_reauthentication_token_in_session
          def stored_reauthentication_token
            session[passkey_reauthentication_token_key]
          end

          # This method is responsible for clearing the reauthentication token from
          # the session.
          #
          # @return [String] the reauthentication token
          # @see passkey_reauthentication_token_key
          def clear_reauthentication_token!
            session.delete(passkey_reauthentication_token_key)
          end

          # This method is responsible for consuming (i.e. retrieving & clearing)
          # the reauthentication token from the session.
          #
          # @return [String] the reauthentication token
          # @see stored_reauthentication_token
          # @see clear_reauthentication_token!
          def consume_reauthentication_token!
            value = stored_reauthentication_token
            clear_reauthentication_token!
            value
          end

          # This method is responsible for validating the given reauthentication token
          # against the one currently in the session.
          #
          # **Note**: Whenever a reauthentication token is checked using `valid_reauthentication_token?`,
          # It will be consumed. This means that a new token will need to be generated & stored
          # (by reauthenticating the user) if there were any issues.
          #
          # @param [String] given_reauthentication_token token to compare store token against
          # @return [Boolean] whether the `given_reauthentication_token` is the same as the
          #         `stored_reauthentication_token`
          # @see consume_reauthentication_token!
          def valid_reauthentication_token?(given_reauthentication_token:)
            Devise.secure_compare(consume_reauthentication_token!, given_reauthentication_token)
          end

          # This method is responsible for generating the key that will be used
          # to store the reauthentication token in the session hash.
          #
          # @return [String] the key that will be used to access the reauthentication token in the session
          def passkey_reauthentication_token_key
            "#{resource_name}_current_reauthentication_token"
          end
        end
      end
    end
  end
end
