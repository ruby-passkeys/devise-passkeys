# frozen_string_literal: true

module Devise
  module Passkeys
    module Controllers
      module SessionsControllerConcern
        extend ActiveSupport::Concern

        included do
          include Warden::WebAuthn::AuthenticationInitiationHelpers
          include Warden::WebAuthn::RackHelpers

          # Prepending is crucial to ensure that the relying party is set in the
          # request.env before the strategy is executed
          prepend_before_action :set_relying_party_in_request_env

          def authentication_challenge_key
            "#{resource_name}_current_webauthn_authentication_challenge"
          end
        end

        def new_challenge
          options_for_authentication = generate_authentication_options(relying_party: relying_party)

          store_challenge_in_session(options_for_authentication: options_for_authentication)

          render json: options_for_authentication
        end

        protected

        def set_relying_party_in_request_env
          raise "need to define relying_party for this SessionsController"
        end
      end
    end
  end
end
