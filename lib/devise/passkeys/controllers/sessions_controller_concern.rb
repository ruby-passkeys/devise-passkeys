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
          options_for_authentication = generate_authentication_options(relying_party: relying_party,
            options: (resource_allow_credentials || {}))

          store_challenge_in_session(options_for_authentication: options_for_authentication)

          render json: options_for_authentication
        end

        protected

        def relying_party
          raise NoMethodError, "need to define relying_party for this #{self.class.name}"
        end

        def resource_allow_credentials
          resource_signing_in ? ({allow: resource_signing_in.passkeys.pluck(:external_id)}) : nil
        end

        def resource_signing_in
          @resource_signing_in ||= resource_class.find_by(email: resource_params[:email])
        end

        def resource_params
          params.require(resource_name).permit(:email)
        end

        def resource_class
          resource_name.to_s.capitalize.constantize
        end

      end
    end
  end
end
