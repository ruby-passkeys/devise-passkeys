# frozen_string_literal: true

require 'shared_user'

class UserPasskey < ActiveRecord::Base

  belongs_to :user, inverse_of: :passkeys

  validates :label, presence: true, allow_blank: false
end
