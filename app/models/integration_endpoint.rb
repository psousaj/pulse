require "digest"

class IntegrationEndpoint < ApplicationRecord
  belongs_to :account

  has_many :integration_event_ingresses, dependent: :delete_all
  has_many :monitor_source_bindings, dependent: :nullify

  attr_reader :plain_secret

  scope :enabled, -> { where(enabled: true) }

  validates :provider, :name, :secret_digest, presence: true

  before_validation :assign_secret_digest, on: :create

  def self.digest(secret)
    Digest::SHA256.hexdigest(secret.to_s)
  end

  def authenticates?(secret)
    digest = self.class.digest(secret)
    ActiveSupport::SecurityUtils.secure_compare(secret_digest, digest)
  end

  def config
    config_json || {}
  end

  def rotate_secret!
    @plain_secret = SecureRandom.hex(24)
    update!(secret_digest: self.class.digest(@plain_secret))
    self
  end

  private

  def assign_secret_digest
    return if secret_digest.present?

    @plain_secret = SecureRandom.hex(24)
    self.secret_digest = self.class.digest(@plain_secret)
  end
end
