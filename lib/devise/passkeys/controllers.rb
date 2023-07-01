# frozen_string_literal: true

require_relative "controllers/concerns/reauthentication"
require_relative "controllers/concerns/reauthentication_challenge"
require_relative "controllers/sessions_controller_concern"
require_relative "controllers/registrations_controller_concern"
require_relative "controllers/reauthentication_controller_concern"
require_relative "controllers/passkeys_controller_concern"

module Devise
  module Passkeys
    # This module contains all the controller-level logic for:
    #
    # - User (resource) registration management (signup/delete account) using passkeys
    # - User (resource) management of their passkeys
    # - User (resource) authentication & reauthenticating using their passkeys
    #
    # Rather than having base classes, `Devise::Passkeys::Controllers` has a series of concerns
    # that can be mixed into your app's controllers. This allows you to change behavior,
    # and does not keep you stuck down a path that could be incompatible with your
    # existing authentication setup.
    #
    # @example
    #   class Users::RegistrationsController < Devise::RegistrationsController
    #     include Devise::Passkeys::Controllers::RegistrationsControllerConcern
    #   end
    #
    #
    #   class Users::SessionsController < Devise::SessionsController
    #     include Devise::Passkeys::Controllers::SessionsControllerConcern
    #     # ... any custom code you need
    #
    #     def relying_party
    #        WebAuthn::RelyingParty.new(...)
    #     end
    #   end
    #
    #   # frozen_string_literal: true
    #
    #   class Users::ReauthenticationController < DeviseController
    #     include Devise::Passkeys::Controllers::ReauthenticationControllerConcern
    #     # ... any custom code you need
    #
    #     def relying_party
    #        WebAuthn::RelyingParty.new(...)
    #     end
    #   end
    #
    #   # frozen_string_literal: true
    #
    #   class Users::PasskeysController < DeviseController
    #     include Devise::Passkeys::Controllers::PasskeysControllerConcern
    #     # ... any custom code you need
    #
    #     def relying_party
    #        WebAuthn::RelyingParty.new(...)
    #     end
    #   end
    #
    # *Note:* The `Devise::Passkeys::Controllers::Concerns` namespace is for:
    # > Code, related to the concerns for controllers, that can be extracted into a standalone
    # > module that can be included & extended as needed for apps that need
    # > to do something custom with their setup.
    # >
    # > https://github.com/ruby-passkeys/devise-passkeys/issues/4#issuecomment-1590357907
    module Controllers
    end
  end
end
