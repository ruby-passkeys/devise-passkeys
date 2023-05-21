# frozen_string_literal: true

module Devise
  module Models
    # PasskeyAuthenticatable model.
    module PasskeyAuthenticatable
      def after_passkey_authentication; end
    end
  end
end
