# frozen_string_literal: true

require_relative "controllers/concerns/Reauthentication"
require_relative "controllers/concerns/reauthentication_challenge"
require_relative "controllers/sessions_controller_concern"
require_relative "controllers/registrations_controller_concern"
require_relative "controllers/reauthentication_controller_concern"
require_relative "controllers/passkeys_controller_concern"

module Devise
  module Passkeys
    module Controllers
    end
  end
end
