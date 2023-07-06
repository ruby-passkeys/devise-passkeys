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

## Add `:passkey_authenticatable`

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

  def after_passkey_authentication(passkey:)
  end
end
```

The Devise-enabled model must have a `webauthn_id` field in the model; which is:

- A string
- Has a unique index

This will allow you to explictly establish the relationship between a user & its passkeys (to help both your app & the user's authenticator with credential management)

## Generate the Model That Will Store Passkeys. Should Have:
- A `has_many :passkeys` association
- A `passkey_class` class method that returns the passkey class
- A `find_for_passkey(passkey)` class method that finds the user for a given passkey

```sh
rails g model Passkey user:references label:string external_id:string:index:uniq public_key:string:index sign_count:integer last_used_at:datetime
```

The following fields are required:

- `label:string` (required, cannot be blank you'll want to scope it to the Devise-enabled model)
- `external_id:string`
- `public_key:string`
- `sign_count:integer`
- `last_used_at:datetime`

It's recommended to add unique indexes on `external_id` and `public_key`

## Generate Custom Devise Controllers & Views 

[Since Devise does not have built-in passkeys support yet](https://github.com/heartcombo/devise/issues/5527), you'll need to customize both the controllers & the views

```shell
rails generate devise:controllers users
rails generate devise:views users
```

If you're trying to keep your codebase small, these instructions only concern the `Users::SessionsController` & `Users::RegistrationsController`, so you can delete any other generated custom controllers if needed. You will likely need to modify the `views/users/shared/*` partials though, because they assume passwords are being used.

## Include the Passkeys Concerns in Your Controllers

Rather than having base classes, `Devise::Passkeys` has a series of concerns that can be mixed into your controllers. This allows you to change behavior, and does not keep you stuck down a path that could be incompatible with your existing authentication setup.

Here are examples of common controllers

```ruby
class Users::RegistrationsController < Devise::RegistrationsController
  include Devise::Passkeys::Controllers::RegistrationsControllerConcern
end


class Users::SessionsController < Devise::SessionsController
  include Devise::Passkeys::Controllers::SessionsControllerConcern
  # ... any custom code you need

  def relying_party
     WebAuthn::RelyingParty.new(...)
  end
end

# frozen_string_literal: true

class Users::ReauthenticationController < DeviseController
  include Devise::Passkeys::Controllers::ReauthenticationControllerConcern
  # ... any custom code you need

  def relying_party
     WebAuthn::RelyingParty.new(...)
  end
end

# frozen_string_literal: true

class Users::PasskeysController < DeviseController
  include Devise::Passkeys::Controllers::PasskeysControllerConcern
  # ... any custom code you need

  def relying_party
     WebAuthn::RelyingParty.new(...)
  end
end

```

## Add Routes

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

# Reimplement Passkeys Authenticatable Module 

You will need to reimplement Passkeys Authenticatable

**Important This will override the module definition with the implementation specific definitions, this points to the specific route, controller, etc. **

Here's an example: 
```ruby
Devise.add_module :passkey_authenticatable,
                  model: 'devise/passkeys/model',
                  route: {session: [nil, :new, :create, :destroy] },
                  controller: 'controller/sessions',
                  strategy: true,
                  no_input: true
```

# FAQs

## What about the Webauthn javascript? Mailers? Error handling?

You will have to implement these, since `Devise::Passkeys` is focused on the authentication handshakes, and each app is different (with different javascript setups, mailer needs, etc.)

## I need to see it in action

Here's a template repo! https://github.com/ruby-passkeys/devise-passkeys-template

## Development

Please see [CONTRIBUTING.md](https://github.com/ruby-passkeys/devise-passkeys/blob/main/CONTRIBUTING.md) for guidance on how to help out!

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ruby-passkeys/devise-passkeys. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/ruby-passkeys/devise-passkeys/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Devise::Passkeys project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/ruby-passkeys/devise-passkeys/blob/main/CODE_OF_CONDUCT.md).


## Acknowledgements

This work is based on [Petr Hlavicka](https://github.com/CiTroNaK)'s [webauthn-with-devise](https://github.com/CiTroNaK/webauthn-with-devise/compare/main...3-passwordless).

The ethos of the library is inspired from [Tiddle](https://github.com/adamniedzielski/tiddle)'s straightforward, minimally-scoped approach.
