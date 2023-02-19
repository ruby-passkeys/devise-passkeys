# frozen_string_literal: true

require 'shared_user'

class UserPasskey < ActiveRecord::Base

  belongs_to :user, inverse_of: :passkeys

  cattr_accessor :validations_performed

  after_validation :after_validation_callback

  validates :label, presence: true, allow_blank: false

  def after_validation_callback
    # used to check in our test if the validations were called
    @@validations_performed = true
  end
end
