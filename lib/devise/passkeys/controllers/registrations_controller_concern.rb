# frozen_string_literal: true

module Devise
  module Passkeys
    module Controllers
      # This concern is responsible for handling registration.
      # Should be included in any controller that handles user registrations. 
      #
      # Module provides necessary before filters, methods, and controller actions related to user (resource) registration and authentication, and defines: 
      #
      # - Generates registration options for WebAuthn and stores the challenge in object session. 
      # - Protected methods for User (resource) Registration, Passkey Creation, User Registration Deletion from session.
      # - Controller actions that facilitate Registration Options, Provide Passkeys.
      # - Extends useful RegistrationHelper methods from Warden::WebAuthn 
      #
      # @example
      #   class RegistrationsController < ApplicationController
      #     include registrationsControllerConcern
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

        # Initializes a new session for user (resource) creation. Stores this challenge in new object session. 
        # Renders response to request out to browser in JSON format.
        # 
        # The following before actions are called:
        #
        # - before_action :require_no_authentication, only: [:new_challenge]
        # - before_action :require_email_and_passkey_label, only: %i[new_challenge create]
        #
        # @see DeviseController#require_no_authentication
        # @see require_email_and_passkey_label
        
        def new_challenge
          options_for_registration = generate_registration_options(
            relying_party: relying_party,
            user_details: user_details_for_registration,
            exclude: exclude_external_ids_for_registration
          )

          store_challenge_in_session(options_for_registration: options_for_registration)

          render json: options_for_registration
        end

        # Creates the User (resource), using the given passkey & email.
        # Calls the parent class's `#create` method, then calls `#create_resource_and_passkey` to finish creating the passkey
        # If the User (resource) was actually persisted
        #
        # The following before actions are called: 
        #
        # - before_action :require_email_and_passkey_label, only: %i[new_challenge create]
        # - before_action :verify_passkey_registration_challenge, only: [:create]
        # - before_action :configure_sign_up_params, only: [:create]
        
        def create
          super do |resource|
            create_resource_and_passkey(resource: resource)
          end
        end

        protected
        
        # Creates a passkey for given User (resource). 
        #

        def create_resource_and_passkey(resource:)
          return unless resource.persisted?

          passkey = create_passkey(resource: resource)

          yield [resource, passkey] if block_given?
          delete_registration_user_id!
        end

        def create_passkey(resource:)
          resource.passkeys.create!(
            label: passkey_params[:passkey_label],
            public_key: @webauthn_credential.public_key,
            external_id: Base64.strict_encode64(@webauthn_credential.raw_id),
            sign_count: @webauthn_credential.sign_count,
            last_used_at: Time.now.utc
          )
        end

        def verify_reauthentication_token
          return if valid_reauthentication_token?(given_reauthentication_token: reauthentication_params[:reauthentication_token])

          render json: { error: find_message(:not_reauthenticated) }, status: :bad_request
        end

        def reauthentication_params
          params.require(:user).permit(:reauthentication_token)
        end

        def update_resource(resource, params)
          resource.update(params)
        end

        # Override if you need to exclude certain external IDs
        def exclude_external_ids_for_registration
          []
        end

        def passkey_params
          params.require(resource_name).permit(:passkey_label, :passkey_credential)
        end

        # @!visibility public

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

        def verify_passkey_registration_challenge
          @webauthn_credential = verify_registration(relying_party: relying_party)
        rescue ::WebAuthn::Error => e
          error_key = Warden::WebAuthn::ErrorKeyFinder.webauthn_error_key(exception: e)
          render json: { message: find_message(error_key) }, status: :bad_request
        end

        # If you have extra params to permit, append them to the sanitizer.
        def configure_sign_up_params
          params[:user][:webauthn_id] = registration_user_id
          devise_parameter_sanitizer.permit(:sign_up, keys: [:webauthn_id])
        end

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
