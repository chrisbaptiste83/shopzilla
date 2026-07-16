class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [ :google_oauth2, :github ]

  has_secure_token :auth_token

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
      # user.name = auth.info.name   # assuming the user model has a name
      # user.image = auth.info.image # assuming the user model has an image
      # If you are using confirmable and the provider is already verified, you can skip confirmation:
      # user.skip_confirmation!
    end
  end

  has_many :orders, dependent: :restrict_with_exception
  has_one_attached :avatar
  has_rich_text :bio

  has_many :download_accesses, dependent: :destroy
  has_many :wishlist_items, dependent: :destroy
  has_many :wishlist_products, through: :wishlist_items, source: :product
  has_many :reviews, dependent: :destroy
  has_many :webauthn_credentials, dependent: :destroy

  after_initialize :generate_webauthn_id, if: :new_record?

  private

  def generate_webauthn_id
    self.webauthn_id ||= WebAuthn.generate_user_id
  end
  def self.ransackable_associations(auth_object = nil)
    [ "orders" ]
  end

  def self.ransackable_attributes(auth_object = nil)
    [ "id", "email", "created_at", "updated_at", "admin" ]
  end
end
