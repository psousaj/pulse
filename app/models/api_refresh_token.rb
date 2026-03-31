class ApiRefreshToken < ApplicationRecord
  belongs_to :account
  belongs_to :user
  belongs_to :api_client

  validates :jti, :token_digest, :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }
end
