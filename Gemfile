# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in devise-passkeys.gemspec
gemspec

group :development, :test do
  gem "appraisal"
  gem "debug"
  gem "rake", "~> 13.0"
  gem "rubocop", "~> 1.21"
  gem "webrick"
  gem "yard"
end

group :test do
  gem "database_cleaner-active_record"
  gem "database_cleaner-mongoid"
  gem "m"
  gem "minitest", "~> 5.0"
  gem "minitest-ci", require: false
  gem "rack"
  gem "simplecov"
end
