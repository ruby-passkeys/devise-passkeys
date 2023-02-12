# frozen_string_literal: true

class UserOnMainApp < ActiveRecord::Base
  self.table_name = 'users'
  include Shim
end
