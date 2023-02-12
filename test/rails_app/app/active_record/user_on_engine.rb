# frozen_string_literal: true

class UserOnEngine < ActiveRecord::Base
  self.table_name = 'users'
  include Shim
end
