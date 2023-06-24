# frozen_string_literal: true

require 'shared_user'

class User < ActiveRecord::Base
  include Shim
  include SharedUser

  has_many :passkeys, class_name: "UserPasskey", dependent: :destroy

  validates :sign_in_count, presence: true

  cattr_accessor :after_passkey_authentication_passkey

  def after_passkey_authentication(passkey:)
    # used to check in our test if the callbacks were called
    @@after_passkey_authentication_passkey = passkey.label
  end
end
