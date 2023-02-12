# frozen_string_literal: true

module SharedUser
  extend ActiveSupport::Concern

  included do
    devise :confirmable, :lockable, :recoverable,
           :rememberable, :timeoutable,
           :trackable, :validatable,
           reconfirmable: false

    attr_accessor :other_key

  end

  def raw_confirmation_token
    @raw_confirmation_token
  end
end
