# frozen_string_literal: true

module Devise
  module Passkeys
    module Controllers
      # This concern should be included in any controller that handles
      # user (`resource`) registration management (ie: signup/deleting an account),
      # and defines:
      #
      # - Useful methods and before filters to streamline user (`resource`) registration management using session variables
      # - Controller actions for:
      #     - Issuing a new WebAuthn challenge
      #     - A `create` action that creates a passkey if the user (`resource`) has been persisted
      # - Helper modules from `Warden::WebAuthn` that are required to complete the registration process
      #
      # The `registration_user_id_key` and `registration_challenge_key` are defined
      # using the `resource_name`, to keep the generated IDs unique between resources
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
      #     include Devise::Passkeys::Controllers::RegistrationsControllerConcern
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
        # The challenge is stored in a session variable, and renders the WebAuthn
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
        # 2. calls `#create_passkey_for_resource` to finish creating the passkey
        #    if the user (`resource`) was actually persisted
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
        # @see create_passkey_for_resource
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
        # The method tests that the user (`resource`) is in the database
        # before saving the passkey for the given user (`resource`).
        #
        #
        # This method also ensures that the generated WebAuthn User ID is deleted from the session to prevent
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
        # Generates a passkey for the given `resource`, using the `resource.passkeys.create!`
        # method with the following attributes:
        #
        # - `label`: The `passkey_params[:passkey_label]`
        # - `public_key`: The `@webauthn_credential.public_key`
        # - `external_id`: The credential ID, strictly encoded as a Base 64 string
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
        # The subset of parameters used when verifying a reauthentication_token
        def reauthentication_params
          params.require(resource_name).permit(:reauthentication_token)
        end

        # @!visibility public
        # An override of `DeviseController`'s implementation, to circumvent the
        # `update_with_password` method
        # @see DeviseController#update_resource
        def update_resource(resource, params)
          resource.update(params)
        end

        # @!visibility public
        # Override this method if you need to exclude certain WebAuthn credentials
        # from a registration request.
        # @see new_challenge
        # @see https://github.com/cedarcode/webauthn-ruby#initiation-phase
        def exclude_external_ids_for_registration
          []
        end

        # @!visibility public
        # The subset of parameters used when verifying the passkey
        def passkey_params
          params.require(resource_name).permit(:passkey_label, :passkey_credential)
        end

        # @!visibility public
        # Verifies that the `sign_up_params` has a value for the devise resource authentication
        # key and `:passkey_label`.
        #
        # If either is missing or blank, a `400 Bad Request` JSON response is rendered.
        #
        # @example
        #  {"error": "Please enter your email address."}
        #  {"error": "Please enter your username."}
        def require_email_and_passkey_label
          if sign_up_params[resource_authentication_key].blank?
            render json: { message: find_message(resource_authentication_key_missing) }, status: :bad_request
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
        # Adds the generated WebAuthn User ID to `devise_parameter_sanitizer`'s permitted keys
        def configure_sign_up_params
          params[resource_name][:webauthn_id] = registration_user_id
          devise_parameter_sanitizer.permit(:sign_up, keys: [:webauthn_id])
        end

        # @!visibility public
        # Prepares the user details for a WebAuthn registration request
        # @see new_challenge
        # @see https://github.com/cedarcode/webauthn-ruby#initiation-phase
        def user_details_for_registration
          store_registration_user_id
          { id: registration_user_id, name: sign_up_params[resource_authentication_key] }
        end

        # @!visibility public
        # Return the value of registration_user_id_key, stored in the session
        def registration_user_id
          session[registration_user_id_key]
        end

        # @!visibility public
        # Delete registration_user_id_key from the session
        def delete_registration_user_id!
          session.delete(registration_user_id_key)
        end

        # @!visibility public
        # Store WebAuthn value for `generate_user_id` in the session
        def store_registration_user_id
          session[registration_user_id_key] = WebAuthn.generate_user_id
        end

        # @!visibility public
        # Return the first authentication key, configured for the Devise resource
        def resource_authentication_key
          (resource || resource_class).authentication_keys.first
        end

        # @!visibility public
        # Return the missing symbol for the first authentication key, configured in Devise
        def resource_authentication_key_missing
          "#{resource_authentication_key}_missing".to_sym
        end
      end
    end
  end
end
