## [0.2.0] - 2023-07-07

### Bugfixes
- Fixed bug with `Devise::Strategies::PasskeyReauthentication` clearing the CSRF token after reauthentication
  - https://github.com/ruby-passkeys/devise-passkeys/pull/45
- Fixed bug where `RegistrationsControllerConcern` was using `:user` as the Strong Parameters key, rather than `resource_key`
  - https://github.com/ruby-passkeys/devise-passkeys/commit/5ef8c83ffe57b3719ab574a01c710ee3ba7dcfb1
- Rename `create_resource_and_passkey` => `create_passkey_for_resource`
  - https://github.com/ruby-passkeys/devise-passkeys/pull/37
- `ReauthenticationControllerConcern` and `SessionsControllerConcern` raise `NoMethodError` if the `relying_party` has not been overridden
  - https://github.com/ruby-passkeys/devise-passkeys/pull/32

### Refactoring

- Refactor PasskeysControllerConcern to have clearer credential verify with `verify_credential_integrity`
  -https://github.com/ruby-passkeys/devise-passkeys/pull/29/commits/f1400cb4b217c20b9e74fda3f55f74284e373d25
- Refactor Controller concerns to not use `Warden::WebAuthn::StrategyHelpers`
  - https://github.com/ruby-passkeys/devise-passkeys/pull/29
- Rename `Devise::Passkeys::Controllers::Concerns::PasskeyReauthentication` => `Devise::Passkeys::Controllers::Concerns::Reauthentication`
  - https://github.com/ruby-passkeys/devise-passkeys/pull/7/
- Add `passkey:` keyword param to `after_passkey_authentication` callback
  - https://github.com/ruby-passkeys/devise-passkeys/pull/26
- Removed unused `:maximum_passkeys_per_user` attribute
  - https://github.com/ruby-passkeys/devise-passkeys/pull/41

### Etc.
- Bump to warden-webauthn 0.2.1
  - https://github.com/ruby-passkeys/devise-passkeys/pull/29/commits/d825ffded91aa98801bdd5530442761aa60538f9
- Use `Warden::WebAuthn::RackHelper.set_relying_party_in_request_env` to streamline setup
  https://github.com/ruby-passkeys/devise-passkeys/pull/29/commits/7b7d50129ebe83b0a224d0ace0e4cff8ea407f4a
- Bump `Devise` requirement to `>= 4.7.1`
  - https://github.com/ruby-passkeys/devise-passkeys/pull/11
- Documentation
    - https://github.com/ruby-passkeys/devise-passkeys/pull/12
    - https://github.com/ruby-passkeys/devise-passkeys/pull/44
    - https://github.com/ruby-passkeys/devise-passkeys/pull/43
    - https://github.com/ruby-passkeys/devise-passkeys/pull/39
    - https://github.com/ruby-passkeys/devise-passkeys/pull/38


## [0.1.0] - 2023-05-07

- Initial release
