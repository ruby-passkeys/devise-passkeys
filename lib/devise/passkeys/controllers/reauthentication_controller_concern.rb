# frozen_string_literal: true

module Devise
  module Passkeys
    module Controllers
      # This concern is responsible for handling reauthentication.
      # It should be included in any controller that handles reauthentication, and defines:
      #
      # - Useful methods to assist with the reauthentication process
      # - Concerns that are required to complete the reauthentication process
      # - Helper modules from `Warden::WebAuthn` that are required to complete the reauthentication process
      #
      # **Note**: the implementing controller **must** define a `relying_party` method in order for
      # reauthentications to work.
      #
      # @example
      #  class ReauthenticationController < ApplicationController
      #    include Devise::Passkeys::Controllers::ReauthenticationControllerConcern
      #
      #    def relying_party
      #       WebAuthn::RelyingParty.new
      #    end
      #  end
      #
      # The `authenticate_scope!` is called as a `before_action` to verify the authentication and set the
      # `resource` for the controller.
      #
      # Likewise, `Warden::WebAuthn::RackHelpers#set_relying_party_in_request_env` is a `before_action` to ensure that the relying party is set in the
      # `request.env` before the Warden strategy is executed
      #
      # @see relying_party
      # @see Devise::Passkeys::Controllers::Concerns::ReauthenticationChallenge
      # @see Devise::Passkeys::Controllers::Concerns::Reauthentication
      # @see Warden::WebAuthn::StrategyHelpers
      # @see Warden::WebAuthn::RackHelpers
      module ReauthenticationControllerConcern
        extend ActiveSupport::Concern

        included do
          include Devise::Passkeys::Controllers::Concerns::Reauthentication
          include Devise::Passkeys::Controllers::Concerns::ReauthenticationChallenge
          include Warden::WebAuthn::AuthenticationInitiationHelpers
          include Warden::WebAuthn::RackHelpers

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

        # A controller action that stores the reauthentication challenge in session
        # and renders the options for authentication from `webauthn-ruby`.
        #
        # The response is rendered as JSON, with a status of `200 OK`.
        #
        # @see Devise::Passkeys::Controllers::Concerns::ReauthenticationChallenge#store_reauthentication_challenge_in_session
        # @see Warden::WebAuthn::AuthenticationInitiationHelpers#generate_authentication_options
        # @see Warden::WebAuthn::RackHelpers#set_relying_party_in_request_env
        def new_challenge
          options_for_authentication = generate_authentication_options(relying_party: relying_party,
                                                                       options: { allow: resource.passkeys.pluck(:external_id) })

          store_reauthentication_challenge_in_session(options_for_authentication: options_for_authentication)

          render json: options_for_authentication
        end

        # A controller action that:
        #
        # 1. Uses the `warden` strategy to authenticate the current user with the defined strategy
        # 2. Calls `sign_in` with `event: :passkey_reauthentication` to verify that the user can authenticate
        # 3. Stores the reauthentication token in the session
        # 4. Renders a JSON object with the reauthentication token
        # 5. Ensures that the reauthentication challenge from the session, regardless of any errors
        #
        # @example
        #  {"reauthentication_token": "abcd1234", "new_csrf_token": "4321dcba"}
        #
        # `prepare_params` is called as a `before_action` to prepare the passkey credential for use by the
        # Warden strategy.
        #
        # Optionally accepts a block that will be executed after the user has been reauthenticated.
        # @see strategy
        # @see Devise::Passkeys::Controllers::Concerns::Reauthentication#store_reauthentication_token_in_session
        # @see prepare_params
        def reauthenticate
          sign_out(resource)
          self.resource = warden.authenticate!(strategy, auth_options)
          sign_in(resource, event: :passkey_reauthentication)
          yield resource if block_given?

          store_reauthentication_token_in_session

          render json: { 
            reauthentication_token: stored_reauthentication_token,
            new_csrf_token: form_authenticity_token
          }
        ensure
          delete_reauthentication_challenge
        end

        protected

        # @!visibility public
        # Prepares the request parameters for use by the Warden strategy
        def prepare_params
          request.params[resource_name] = ActionController::Parameters.new({
                                                                             passkey_credential: params[:passkey_credential]
                                                                           })
        end

        # @!visibility public
        # A method that can be overridden to customize the Warden stratey used.
        # @return [Symbol] The key that identifies which `Warden` strategy will be used to handle the
        #                  authentication flow for the reauthentication. Defaults to `:passkey_reauthentication`
        def strategy
          :passkey_reauthentication
        end

        def auth_options
          { scope: resource_name, recall: root_path }
        end

        def delete_reauthentication_challenge
          session.delete(passkey_reauthentication_challenge_session_key)
        end

        # @!visibility public
        # @abstract
        # The method that returns the `WebAuthn::RelyingParty` for this request.
        # @return [WebAuthn::RelyingParty] when overridden, this method should return a `WebAuthn::RelyingParty` instance
        def relying_party
          raise NoMethodError, "need to define relying_party for this #{self.class.name}"
        end
      end
    end
  end
end
