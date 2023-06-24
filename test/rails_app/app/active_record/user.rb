# frozen_string_literal: true

require 'shared_user'

class User < ActiveRecord::Base
  include Shim
  include SharedUser

  has_many :passkeys, class_name: "UserPasskey", dependent: :destroy

  validates :sign_in_count, presence: true
end
