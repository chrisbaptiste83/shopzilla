class DownloadAccess < ApplicationRecord
  belongs_to :user
  belongs_to :product
  belongs_to :order
  
  validates :access_token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  
  before_create :generate_access_token
  
  scope :active, -> { where('expires_at > ?', Time.current) }
  
  def expired?
    expires_at < Time.current
  end
  
  private
  
  def generate_access_token
    self.access_token = SecureRandom.urlsafe_base64(32)
  end
end
