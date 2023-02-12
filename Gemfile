# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in devise-passkeys.gemspec
gemspec

group :development, :test do
  gem "debug"
  gem "rake", "~> 13.0"
  gem "rubocop", "~> 1.21"
end

group :test do
  gem "m"
  gem "minitest", "~> 5.0"
  gem "rack"
  gem "simplecov"
  gem "database_cleaner-active_record"
  gem "database_cleaner-mongoid"
end

gem "warden-webauthn", git: "https://github.com/ruby-passkeys/warden-webauthn"