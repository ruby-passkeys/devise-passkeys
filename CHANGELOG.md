## [Unreleased]

- Refactor Controller concerns to not use `Warden::WebAuthn::StrategyHelpers`
  - https://github.com/ruby-passkeys/devise-passkeys/pull/29
- Rename `Devise::Passkeys::Controllers::Concerns::PasskeyReauthentication` => `Devise::Passkeys::Controllers::Concerns::Reauthentication`
  - https://github.com/ruby-passkeys/devise-passkeys/pull/7/
- Bump `Devise` requirement to `>= 4.7.1`
  - https://github.com/ruby-passkeys/devise-passkeys/pull/11
- Document `Devise::Passkeys::Model`
  - https://github.com/ruby-passkeys/devise-passkeys/pull/12

## [0.1.0] - 2023-05-07

- Initial release
