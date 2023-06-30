# frozen_string_literal: true

require_relative "controllers/concerns/reauthentication"
require_relative "controllers/concerns/reauthentication_challenge"
require_relative "controllers/sessions_controller_concern"
require_relative "controllers/registrations_controller_concern"
require_relative "controllers/reauthentication_controller_concern"
require_relative "controllers/passkeys_controller_concern"

module Devise
  module Passkeys
    # Passkeys Controllers encapsulate all methods that implement actions related to the Passkeys
    #   The most common uses cases are: registration, authentication, and reauthentication
    #   Other controllers and concerns should all inherit from here. As the following:
    #     ReauthenticationChallenge concern: provide methods for reauthentication challenge
    #     Reauthentication concern: provide methods for reauthentication
    #     PasskeysControllerConcern: provide methods to manage passkeys
    #     ReauthenticationControllerConcern: provide methods for handling reauthentication
    #     RegistrationsControllerConcern: provide methods for handling registration
    #     SessionsControllerConcern: provide methods for handing session
    module Controllers
    end
  end
end
