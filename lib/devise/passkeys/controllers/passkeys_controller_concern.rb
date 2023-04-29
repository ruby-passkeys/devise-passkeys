# frozen_string_literal: true

module Devise
  module Passkeys
    module Controllers
      module PasskeysControllerConcern
        extend ActiveSupport::Concern

        included do
          include Devise::Passkeys::Controllers::Concerns::PasskeyReauthentication
          include Devise::Passkeys::Controllers::Concerns::ReauthenticationChallenge
          include Warden::WebAuthn::AuthenticationInitiationHelpers
          include Warden::WebAuthn::RegistrationHelpers
          include Warden::WebAuthn::StrategyHelpers

          prepend_before_action :authenticate_scope!
          before_action :ensure_at_least_one_passkey, only: %i[new_destroy_challenge destroy]
          before_action :find_passkey, only: %i[new_destroy_challenge destroy]

          before_action :verify_passkey_challenge, only: [:create]
          before_action :verify_reauthentication_token, only: %i[create destroy]

          # Authenticates the current scope and gets the current resource from the session.
          def authenticate_scope!
            send(:"authenticate_#{resource_name}!", force: true)
            self.resource = send(:"current_#{resource_name}")
          end

          def registration_challenge_key
            "#{resource_name}_passkey_creation_challenge"
          end

          def errors
            warden.errors
          end

          def raw_credential
            passkey_params[:credential]
          end
        end

        def new_create_challenge
          options_for_registration = generate_registration_options(
            relying_party: relying_party,
            user_details: user_details_for_registration,
            exclude: exclude_external_ids_for_registration
          )

          store_challenge_in_session(options_for_registration: options_for_registration)

          render json: options_for_registration
        end

        def create
          create_passkey(resource: resource)
        end

        def new_destroy_challenge
          allowed_passkeys = (resource.passkeys - [@passkey])

          options_for_authentication = generate_authentication_options(relying_party: relying_party,
                                                                       options: { allow: allowed_passkeys.pluck(:external_id) })

          store_reauthentication_challenge_in_session(options_for_authentication: options_for_authentication)

          render json: options_for_authentication
        end

        def destroy
          @passkey.destroy
          redirect_to root_path
        end

        protected

        def create_passkey(resource:)
          passkey = resource.passkeys.create!(
            label: passkey_params[:label],
            public_key: @webauthn_credential.public_key,
            external_id: Base64.strict_encode64(@webauthn_credential.raw_id),
            sign_count: @webauthn_credential.sign_count,
            last_used_at: nil
          )
          yield [resource, passkey] if block_given?
          redirect_to root_path
        end

        def exclude_external_ids_for_registration
          resource.passkeys.pluck(:external_id)
        end

        def user_details_for_registration
          { id: resource.webauthn_id, name: resource.email }
        end

        def verify_passkey_challenge
          if parsed_credential.nil?
            render json: { message: find_message(:credential_missing_or_could_not_be_parsed) }, status: :bad_request
            delete_registration_challenge
            return false
          end
          begin
            @webauthn_credential = verify_registration(relying_party: relying_party)
          rescue ::WebAuthn::Error => e
            error_key = Warden::WebAuthn::ErrorKeyFinder.webauthn_error_key(exception: e)
            render json: { message: find_message(error_key) }, status: :bad_request
          end
        end

        def passkey_params
          params.require(:passkey).permit(:label, :credential)
        end

        def ensure_at_least_one_passkey
          return unless current_user.passkeys.count <= 1

          render json: { error: find_message(:must_be_at_least_one_passkey) }, status: :bad_request
        end

        def find_passkey
          @passkey = resource.passkeys.where(id: params[:id]).first
          return unless @passkey.nil?

          head :not_found
          nil
        end

        def verify_reauthentication_token
          return if valid_reauthentication_token?(given_reauthentication_token: reauthentication_params[:reauthentication_token])

          render json: { error: find_message(:not_reauthenticated) }, status: :bad_request
        end

        def reauthentication_params
          params.require(:passkey).permit(:reauthentication_token)
        end
      end
    end
  end
end
