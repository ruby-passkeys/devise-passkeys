# frozen_string_literal: true

Bundler.require(:test)
SimpleCov.start do
  add_filter "/test/"
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "devise/passkeys"

require "minitest/autorun"
