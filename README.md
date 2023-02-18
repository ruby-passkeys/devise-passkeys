# Devise::Passkeys

This Devise extension allows you to use passkeys instead of passwords for user authentication.

`Devise::Passkeys` is lightweight and non-configurable. It does what it has to do and leaves some manual implementation to you.


# Installation

Add this line to your application's Gemfile:
```ruby
gem 'devise-passkeys'
```
And then execute:

```sh
$ bundle
```

# Usage

0. Temporary step: copy `app/controllers/devise/passkeys/` controller code from template repo

_This is a temporary step until the gem can implement a lightweight Rails engine_

The files should be stored in: `app/controllers/devise/passkeys/**/*`

1. Add `:passkey_authenticatable` in your Devise-enabled model

```ruby
class User < ApplicationRecord
  devise :passkey_authenticatable, ...

  has_many :passkeys

  def self.passkeys_class
    Passkey
  end

  def self.find_for_passkey(passkey)
    self.find_by(id: passkey.user.id)
  end

  def after_passkey_authentication
  end
end
```

The Devise-enabled model must have a `webauthn_id` field in the model; which is:

- A string
- Has a unique index

This will allow you to explictly establish the relationship between a user & its passkeys (to help both your app & the user's authenticator with credential management)

2. Generate the model that will store passkeys. The model name is not important, but the Devise-enabled model should have:
- A `has_many :passkeys` association
- A `passkey_class` class method that returns the passkey class
- A `find_for_passkey(passkey)` class method that finds the user for a given passkey

```sh
rails g model Passkey user:references label:string external_id:string:index:uniq public_key:string:index sign_count:integer last_used_at:datetime
```

The following fields are required:

- `label:string`
- `external_id:string`
- `public_key:string`
- `sign_count:integer`
- `last_used_at:datetime`

It's recommended to add unique indexes on `external_id` and `public_key`

3. Generate custom devise controllers & views for your Devise-enabled model

[Since Devise does not have built-in passkeys support yet](https://github.com/heartcombo/devise/issues/5527), you'll need to customize both the controllers & the views

```shell
rails generate devise:controllers users
rails generate devise:views users
```

If you're trying to keep your codebase small, these instructions only concern the `Users::SessionsController` & `Users::RegistrationsController`, so you can delete any other generated custom controllers if needed. You will likely need to modify the `views/users/shared/*` partials though, because they assume passwords are being used.

4. Customize `Users::RegistrationsController`


Inheriting from `Devise::Passkeys::Controllers::RegistrationsController` provides you with a build in `new_challenge` method; which you'll need to setup in your routes.

You'll need to setup the `relying_party`, following the documentation in the [`webauthn-ruby` advanced configuration](https://github.com/cedarcode/webauthn-ruby/blob/master/docs/advanced_configuration.md)

```ruby
class Users::RegistrationsController < Devise::Passkeys::RegistrationsController
  # ... any custom code you need

  def relying_party
     WebAuthn::RelyingParty.new(...)
  end
end
```

5. Customize `Users::SessionsController`

Inheriting from `Devise::Passkeys::Controllers::SessionsController` provides you with a build in `new_challenge` method; which you'll need to setup in your routes.

You'll need to setup the `relying_party`, following the documentation in the [`webauthn-ruby` advanced configuration](https://github.com/cedarcode/webauthn-ruby/blob/master/docs/advanced_configuration.md). You'll also need to make sure the `set_relying_party_in_request_env` uses said relying party.

```ruby
class Users::SessionsController < Devise::Passkeys::SessionsController
  # ... any custom code you need

  def relying_party
     WebAuthn::RelyingParty.new(...)
  end

  def set_relying_party_in_request_env
    request.env[relying_party_key] = relying_party
  end
end
```

5. Customize `Users::ReauthenticationController`

Inheriting from `Devise::Passkeys::Controllers::ReauthenticationController` provides you with a build in `new_challenge` method; which you'll need to setup in your routes.

You'll need to setup the `relying_party`, following the documentation in the [`webauthn-ruby` advanced configuration](https://github.com/cedarcode/webauthn-ruby/blob/master/docs/advanced_configuration.md). You'll also need to make sure the `set_relying_party_in_request_env` uses said relying party.

```ruby
class Users::ReauthenticationController < Devise::Passkeys::ReauthenticationController
  # ... any custom code you need

  def relying_party
     WebAuthn::RelyingParty.new(...)
  end

  def set_relying_party_in_request_env
    request.env[relying_party_key] = relying_party
  end
end
```

5. Customize `Users::PasskeysController`

Inheriting from `Devise::Passkeys::Controllers::PasskeysController` provides you with all the logic you'll need to setup in your routes.

You'll need to setup the `relying_party`, following the documentation in the [`webauthn-ruby` advanced configuration](https://github.com/cedarcode/webauthn-ruby/blob/master/docs/advanced_configuration.md). You'll also need to make sure the `set_relying_party_in_request_env` uses said relying party.

```ruby
class Users::PasskeysController < Devise::Passkeys::PasskeysController
  # ... any custom code you need

  def relying_party
     WebAuthn::RelyingParty.new(...)
  end

  def set_relying_party_in_request_env
    request.env[relying_party_key] = relying_party
  end
end
```

6. Add necessary routes

Given the customization routes usually require, you'll need to hook up the routes yourself. Here's an example:

```ruby
devise_for :users, controllers: {
  registrations: 'users/registrations',
  sessions: 'users/sessions'
}

devise_scope :user do
  post 'sign_up/new_challenge', to: 'users/registrations#new_challenge', as: :new_user_registration_challenge
  post 'sign_in/new_challenge', to: 'users/sessions#new_challenge', as: :new_user_session_challenge

  post 'reauthenticate/new_challenge', to: 'users/reauthentication#new_challenge', as: :new_user_reauthentication_challenge
  post 'reauthenticate', to: 'users/reauthentication#reauthenticate', as: :user_reauthentication

  namespace :users do
    resources :passkeys, only: [:index, :create, :destroy] do
      collection do
        post :new_create_challenge
      end

      member do
        post :new_destroy_challenge
      end
    end
  end
end
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/devise-passkeys. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/devise-passkeys/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Devise::Passkeys project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/devise-passkeys/blob/main/CODE_OF_CONDUCT.md).


## Acknowledgements

This work is based on [Petr Hlavicka](https://github.com/CiTroNaK)'s [webauthn-with-devise](https://github.com/CiTroNaK/webauthn-with-devise/compare/main...3-passwordless).

The ethos of the library is inspired from [Tiddle](https://github.com/adamniedzielski/tiddle)'s straightforward, minimally-scoped approach.