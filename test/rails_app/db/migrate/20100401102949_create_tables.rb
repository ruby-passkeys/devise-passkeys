# frozen_string_literal: true

superclass = ActiveRecord::Migration
# TODO: Inherit from the 5.0 Migration class directly when we drop support for Rails 4.
superclass = ActiveRecord::Migration[5.0] if superclass.respond_to?(:[])

class CreateTables < superclass
  def self.up
    create_table :users do |t|
      t.string :username

      ## Database authenticatable
      t.string :email,              null: false, default: ""

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable
      t.integer  :sign_in_count, default: 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      ## Confirmable
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      # t.string   :unconfirmed_email # Only if using reconfirmable

      ## Lockable
      t.integer  :failed_attempts, default: 0 # Only if lock strategy is :failed_attempts
      t.string   :unlock_token # Only if unlock strategy is :email or :both
      t.datetime :locked_at

      t.timestamps null: false
    end

    create_table :admins do |t|
      ## Database authenticatable
      t.string :email,              null: true
      t.string :encrypted_password, null: true

      ## Rememberable
      t.datetime :remember_created_at

      ## Confirmable
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email # Only if using reconfirmable

      ## Lockable
      t.datetime :locked_at

      ## Attribute for testing route blocks
      t.boolean :active, default: false

      t.timestamps null: false
    end

    create_table :user_passkeys do |t|
      t.integer :user_id, null: false
      t.string :label, null: false

      t.string :external_id, null: false
      t.string :public_key, null: false
      t.integer :sign_count, default: 0, null: false

      t.datetime :last_used_at

      t.timestamps null: false
    end
  end

  def self.down
    drop_table :users
    drop_table :admins
  end
end
