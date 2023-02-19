# frozen_string_literal: true

module Devise
  module Passkeys
    module Controllers
      module ReauthenticationControllerConcern
        extend ActiveSupport::Concern

        included do
          include Devise::Passkeys::Controllers::Concerns::PasskeyReauthentication
          include Devise::Passkeys::Controllers::Concerns::ReauthenticationChallenge
          include Warden::WebAuthn::AuthenticationInitiationHelpers
          include Warden::WebAuthn::StrategyHelpers

          prepend_before_action :authenticate_scope!

          before_action :prepare_params, only: [:reauthenticate]

          # Prepending is crucial to ensure that the relying party is set in the
          # request.env before the strategy is executed
          prepend_before_action :set_relying_party_in_request_env

          # Authenticates the current scope and gets the current resource from the session.
          def authenticate_scope!
            send(:"authenticate_#{resource_name}!", force: true)
            self.resource = send(:"current_#{resource_name}")
          end
        end

        def new_challenge
          options_for_authentication = generate_authentication_options(relying_party: relying_party, options: {allow: resource.passkeys.pluck(:external_id)})

          store_reauthentication_challenge_in_session(options_for_authentication: options_for_authentication)

          render json: options_for_authentication
        end

        def reauthenticate
          self.resource = warden.authenticate!(auth_options)
          sign_in(resource, event: :passkey_reauthentication)
          yield resource if block_given?

          store_reauthentication_token_in_session

          render json: {reauthentication_token: stored_reauthentication_token}
        ensure
          delete_reauthentication_challenge
        end

        protected

        def prepare_params
          params[resource_name] = {
            passkey_credential: params[:passkey_credential]
          }
        end

        def auth_options
          { scope: resource_name, recall: root_path }
        end

        def delete_reauthentication_challenge
          session.delete(passkey_reauthentication_challenge_session_key)
        end

        def set_relying_party_in_request_env
          raise RuntimeError, "need to define relying_party for this SessionsController"
        end

      end
    end
  end
end