module Devise
  module Passkeys
    class PasskeyIssuer
      def self.build
        new
      end

      def create_and_return_passkey(resource:, label:, webauthn_credential:, extra_attributes: {})
        passkey_class = passkey_class(resource)

        resource.passkeys.create!({
          label: label,
          public_key: webauthn_credential.public_key,
          external_id: Base64.strict_encode64(webauthn_credential.raw_id),
          sign_count: webauthn_credential.sign_count,
          last_used_at: nil
        }.merge(extra_attributes))
      end


      class CredentialFinder
        attr_reader :resource_class

        def initialize(resource_class:)
          @resource_class = resource_class
        end

        def find_with_credential_id(encoded_credential_id)
          resource_class.passkeys_class.where(external_id: encoded_credential_id).first
        end
      end

      private

      attr_accessor :maximum_passkeys_per_user

      def passkey_class(resource)
        if resource.respond_to?(:association) # ActiveRecord
          resource.association(:passkeys).klass
        elsif resource.respond_to?(:relations) # Mongoid
          resource.relations["passkeys"].klass
        else
          raise "Cannot determine passkey class, unsupported ORM/ODM?"
        end
      end
    end
  end
end