# frozen_string_literal: true

require_relative "lib/devise/passkeys/version"

Gem::Specification.new do |spec|
  spec.name = "devise-passkeys"
  spec.version = Devise::Passkeys::VERSION
  spec.authors = ["Thomas Cannon"]
  spec.email = ["tcannon00@gmail.com"]

  spec.summary = "Use passkeys instead of passwords for Devise"
  spec.description = "A Devise extension to use passkeys instead of passwords for authentication, using warden-webauthn"
  spec.homepage = "https://github.com/ruby-passkeys/devise-passkeys"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ruby-passkeys/devise-passkeys"
  spec.metadata["changelog_uri"] = "https://github.com/ruby-passkeys/devise-passkeys/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "devise"
  spec.add_dependency "warden-webauthn", ">= 0.2.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata["rubygems_mfa_required"] = "true"
end
