## [Unreleased]

- `ReauthenticationControllerConcern` and `SessionsControllerConcern` raise `NoMethodError` if the `relying_party` has not been overridden
  - https://github.com/ruby-passkeys/devise-passkeys/pull/32
- [Bump to warden-webauthn 0.2.1](https://github.com/ruby-passkeys/devise-passkeys/pull/29/commits/d825ffded91aa98801bdd5530442761aa60538f9)
- [Use `Warden::WebAuthn::RackHelper.set_relying_party_in_request_env` to streamline setup](https://github.com/ruby-passkeys/devise-passkeys/pull/29/commits/7b7d50129ebe83b0a224d0ace0e4cff8ea407f4a)
- [Refactor PasskeysControllerConcern to have clearer credential verify with `verify_credential_integrity`](https://github.com/ruby-passkeys/devise-passkeys/pull/29/commits/f1400cb4b217c20b9e74fda3f55f74284e373d25)
- Refactor Controller concerns to not use `Warden::WebAuthn::StrategyHelpers`
  - https://github.com/ruby-passkeys/devise-passkeys/pull/29
- Rename `Devise::Passkeys::Controllers::Concerns::PasskeyReauthentication` => `Devise::Passkeys::Controllers::Concerns::Reauthentication`
  - https://github.com/ruby-passkeys/devise-passkeys/pull/7/
- Bump `Devise` requirement to `>= 4.7.1`
  - https://github.com/ruby-passkeys/devise-passkeys/pull/11
- Document `Devise::Passkeys::Model`
  - https://github.com/ruby-passkeys/devise-passkeys/pull/12
- Add `passkey:` keyword param to `after_passkey_authentication` callback
  - https://github.com/ruby-passkeys/devise-passkeys/pull/26

## [0.1.0] - 2023-05-07

- Initial release
