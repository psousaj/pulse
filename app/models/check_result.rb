class CheckResult < ApplicationRecord
  belongs_to :account
  belongs_to :service
  belongs_to :service_check

  enum :status, {
    up: "up",
    degraded: "degraded",
    down: "down",
    error: "error"
  }, default: :up, validate: true

  scope :recent, -> { order(created_at: :desc) }

  def success?
    up? || degraded?
  end

  def failure?
    down? || error?
  end
end
