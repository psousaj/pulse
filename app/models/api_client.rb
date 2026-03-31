require "digest"

class ApiClient < ApplicationRecord
  belongs_to :account

  has_many :api_access_tokens, dependent: :delete_all
  has_many :api_refresh_tokens, dependent: :delete_all

  attr_reader :plain_client_secret

  validates :name, presence: true
  validates :client_uid, presence: true, uniqueness: true
  validates :client_secret_digest, presence: true

  before_validation :assign_credentials, on: :create

  def self.digest(raw)
    Digest::SHA256.hexdigest(raw.to_s)
  end

  private

  def assign_credentials
    self.client_uid ||= SecureRandom.uuid

    return if client_secret_digest.present?

    @plain_client_secret = SecureRandom.hex(32)
    self.client_secret_digest = self.class.digest(@plain_client_secret)
  end
end
