# frozen_string_literal: true

module Devise
  module Passkeys
    module Controllers
      # This concern should be included in any controller that handles
      # user (`resource`) registration management (signup/delete account),
      # and defines:
      #
      # - Useful methods and before filters to streamline user (`resource`) registration management using session variables
      # - Controller actions for issuing a new WebAuthn challenge, and a `create`
      #   action that creates a passkey if the user (`resource`) has been persisted
      # - Helper modules from `Warden::WebAuthn` that are required to complete the registration process
      #
      # The `registration_user_id_key` and `registration_challenge_key` are defined
      # using the `resource_name` to keep the generated IDs unique between resources
      # during the registration process.
      #
      # A `raw_credential` method is provided to streamline access to
      # `passkey_params[:passkey_credential]`.
      #
      # **Note**: the implementing controller **must** define a `relying_party` method in order for
      # registrations to work.
      #
      # @example
      #   class RegistrationsController < ApplicationController
      #     include registrationsControllerConcern
      #
      #     def relying_party
      #       WebAuthn::RelyingParty.new
      #     end
      #   end
      #
      #
      # @see Devise::Passkeys::Controllers::Concerns::Reauthentication
      # @see Warden::WebAuthn::RegistrationHelpers
      module RegistrationsControllerConcern
        extend ActiveSupport::Concern

        included do
          include Devise::Passkeys::Controllers::Concerns::Reauthentication
          include Warden::WebAuthn::RegistrationHelpers

          before_action :require_no_authentication, only: [:new_challenge]
          before_action :require_email_and_passkey_label, only: %i[new_challenge create]
          before_action :verify_passkey_registration_challenge, only: [:create]
          before_action :configure_sign_up_params, only: [:create]

          before_action :verify_reauthentication_token, only: %i[update destroy]

          def registration_user_id_key
            "#{resource_name}_current_webauthn_user_id"
          end

          def registration_challenge_key
            "#{resource_name}_current_webauthn_registration_challenge"
          end

          def raw_credential
            passkey_params[:passkey_credential]
          end
        end

        # This controller action issues a new challenge for the registration handshake.
        #
        # The challenge is stored in the session variable, and renders the WebAuthn
        # registration options as a JSON response.
        #
        # The following before filters are called:
        #
        # - `require_no_authentication`
        # - `require_email_and_passkey_label`
        #
        # @see DeviseController#require_no_authentication
        # @see require_email_and_passkey_label
        # @see Warden::WebAuthn#generate_registration_options
        # @see https://github.com/cedarcode/webauthn-ruby#initiation-phase
        def new_challenge
          options_for_registration = generate_registration_options(
            relying_party: relying_party,
            user_details: user_details_for_registration,
            exclude: exclude_external_ids_for_registration
          )

          store_challenge_in_session(options_for_registration: options_for_registration)

          render json: options_for_registration
        end

        # This controller action creates a new user (`resource`), using the given
        # email & passkey. It:
        #
        # 1. calls the parent class's `#create` method
        # 2. calls `#create_resource_and_passkey` to finish creating the passkey
        #    If the user (`resource`) was actually persisted.
        # 3. Finishes the rest of the parent class's `#create` method
        #
        #
        # The following before actions are called:
        #
        # - `require_email_and_passkey_label`
        # - `verify_passkey_registration_challenge`
        # - `configure_sign_up_params`
        #
        # @see require_email_and_passkey_label
        # @see verify_passkey_registration_challenge
        # @see configure_sign_up_params
        def create
          super do |resource|
            create_passkey_for_resource(resource: resource)
          end
        end

        protected

        # @!visibility public
        #
        # Creates a passkey for given user (`resource`).
        #
        # The method tests that the user (`resource`) has been saved and is in the database,
        # before generating a passkey assigned to said user.
        #
        # Will yield an array with user (`resource`) and Passkey after code block is passed through method.
        #
        # This method also ensures that the generated WebAuthn ID is deleted from the session to prevent
        # data leaks.
        #
        #
        # @yield [resource, passkey] The provided `resource` and the newly created passkey.
        # @see create_passkey
        def create_passkey_for_resource(resource:)
          return unless resource.persisted?

          passkey = create_passkey(resource: resource)

          yield [resource, passkey] if block_given?
          delete_registration_user_id!
        end

        # @!visibility public
        #
        # Generates a passkey for the given `resource`, using the `resouse.passkeys.create!`
        # method with the following attributes:
        #
        # - `label`: The `passkey_params[:passkey_label]`
        # - `public_key`: The `@webauthn_credential.public_key`
        # - `external_id`: The credential ID, stricly encoded as a Base64 string
        # - `sign_count`: The `@webauthn_credential.sign_count`
        # - `last_used_at`: The current time, since this is the first time the passkey is being used
        #
        def create_passkey(resource:)
          resource.passkeys.create!(
            label: passkey_params[:passkey_label],
            public_key: @webauthn_credential.public_key,
            external_id: Base64.strict_encode64(@webauthn_credential.raw_id),
            sign_count: @webauthn_credential.sign_count,
            last_used_at: Time.now.utc
          )
        end

        # @!visibility public
        #
        # Verifies that the given reauthentication token matches the
        # expected value stored in the session.
        #
        # If the reauthentication token is not valid,
        # a `400 Bad Request` JSON response is rendered.
        #
        # @example
        #  {"error": "Please reauthenticate to continue."}
        #
        # @see reauthentication_params
        # @see Devise::Passkeys::Controllers::Concerns::Reauthentication#valid_reauthentication_token?
        def verify_reauthentication_token
          return if valid_reauthentication_token?(given_reauthentication_token: reauthentication_params[:reauthentication_token])

          render json: { error: find_message(:not_reauthenticated) }, status: :bad_request
        end

        # @!visibility public
        def reauthentication_params
          params.require(:user).permit(:reauthentication_token)
        end

        # @!visibility public
        def update_resource(resource, params)
          resource.update(params)
        end

        # @!visibility public
        # Override if you need to exclude certain webauthn credentials
        # from a registration request.
        # @see new_challenge
        # @see https://github.com/cedarcode/webauthn-ruby#initiation-phase
        def exclude_external_ids_for_registration
          []
        end

        # @!visibility public
        def passkey_params
          params.require(resource_name).permit(:passkey_label, :passkey_credential)
        end

        # @!visibility public
        # Verifies that the `sign_up_params` has an `:email` and `:passkey_label`.
        #
        # If either is missing or blank, a `400 Bad Request` JSON response is rendered.
        #
        # @example
        #  {"error": "Please enter your email address."}
        def require_email_and_passkey_label
          if sign_up_params[:email].blank?
            render json: { message: find_message(:email_missing) }, status: :bad_request
            return false
          end

          if passkey_params[:passkey_label].blank?
            render json: { message: find_message(:passkey_label_missing) }, status: :bad_request
            return false
          end

          true
        end

        # @!visibility public
        # Verifies the registration challenge is correct.
        #
        # If the challenge failed, a `400 Bad Request` JSON
        # response is rendered.
        #
        # @example
        #  {"error": "Please try a different passkey."}
        #
        # @see Warden::WebAuthn::RegistrationHelpers#verify_registration
        # @see https://github.com/cedarcode/webauthn-ruby#verification-phase
        # @see Warden::WebAuthn::ErrorKeyFinder#webauthn_error_key
        def verify_passkey_registration_challenge
          @webauthn_credential = verify_registration(relying_party: relying_party)
        rescue ::WebAuthn::Error => e
          error_key = Warden::WebAuthn::ErrorKeyFinder.webauthn_error_key(exception: e)
          render json: { message: find_message(error_key) }, status: :bad_request
        end

        # @!visibility public
        # If you have extra params to permit, append them to the sanitizer.
        def configure_sign_up_params
          params[:user][:webauthn_id] = registration_user_id
          devise_parameter_sanitizer.permit(:sign_up, keys: [:webauthn_id])
        end

        # @!visibility public
        def user_details_for_registration
          store_registration_user_id
          { id: registration_user_id, name: sign_up_params[:email] }
        end

        def registration_user_id
          session[registration_user_id_key]
        end

        def delete_registration_user_id!
          session.delete(registration_user_id_key)
        end

        def store_registration_user_id
          session[registration_user_id_key] = WebAuthn.generate_user_id
        end
      end
    end
  end
end
