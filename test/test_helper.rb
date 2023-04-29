# frozen_string_literal: true

Bundler.require(:test)
SimpleCov.start do
  add_filter "/test/"
end

ENV["RAILS_ENV"] = "test"
DEVISE_ORM = (ENV["DEVISE_ORM"] || :active_record).to_sym
puts "\n==> Devise.orm = #{DEVISE_ORM.inspect}"
require "rails_app/config/environment"
require "rails/test_help"
require "test_helper/orm/#{DEVISE_ORM}"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "devise/passkeys"

require "minitest/autorun"

if ENV["CIRCLECI"]
  require 'minitest/ci'
  Minitest::Ci.report_dir = "#{Minitest::Ci.report_dir}/#{Rails.version}"
end