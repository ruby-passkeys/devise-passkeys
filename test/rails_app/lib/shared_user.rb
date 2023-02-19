# frozen_string_literal: true

module SharedUser
  extend ActiveSupport::Concern

  included do
    devise :passkey_authenticatable, :registerable

    attr_accessor :other_key

    def self.passkeys_class
      UserPasskey
    end

    def self.find_for_passkey(passkey)
      self.find_by(id: passkey.user.id)
    end

  end

  def raw_confirmation_token
    @raw_confirmation_token
  end
end
