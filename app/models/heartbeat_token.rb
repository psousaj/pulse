require "digest"

class HeartbeatToken < ApplicationRecord
  belongs_to :account
  belongs_to :service
  belongs_to :monitor, class_name: "PulseMonitor", optional: true

  attr_reader :plain_token

  validates :token_digest, presence: true, uniqueness: true
  validates :expected_interval_seconds, numericality: { greater_than: 0 }
  validates :grace_seconds, numericality: { greater_than_or_equal_to: 0 }

  before_validation :assign_token_digest, on: :create

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token.to_s)
  end

  def mark_seen!(at: Time.current)
    update!(last_heartbeat_at: at, next_expected_at: at + expected_interval_seconds)
  end

  def rotate_token!
    @plain_token = SecureRandom.hex(24)
    update!(token_digest: self.class.digest(@plain_token))
    self
  end

  private

  def assign_token_digest
    return if token_digest.present?

    @plain_token = SecureRandom.hex(24)
    self.token_digest = self.class.digest(@plain_token)
  end
end
