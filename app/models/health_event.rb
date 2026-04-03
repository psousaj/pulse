class HealthEvent < ApplicationRecord
  belongs_to :account
  belongs_to :service, optional: true
  belongs_to :monitor, class_name: "PulseMonitor"
  belongs_to :monitor_source_binding, optional: true

  has_many :opening_incidents, class_name: "Incident", foreign_key: :first_health_event_id, dependent: :nullify
  has_many :latest_incidents, class_name: "Incident", foreign_key: :last_health_event_id, dependent: :nullify

  enum :source, {
    internal: "internal",
    integration: "integration",
    heartbeat: "heartbeat"
  }, validate: true

  enum :status, {
    up: "up",
    degraded: "degraded",
    down: "down"
  }, validate: true

  scope :recent, -> { order(checked_at: :desc, id: :desc) }
  scope :authoritative, -> { where(authoritative: true) }

  validates :checked_at, presence: true

  attr_readonly :account_id,
    :service_id,
    :monitor_id,
    :monitor_source_binding_id,
    :source,
    :status,
    :authoritative,
    :latency_ms,
    :ttfb_ms,
    :tls_ms,
    :dns_ms,
    :screenshot_path,
    :error_message,
    :metadata_json,
    :checked_at

  before_update :prevent_mutation

  def failure?
    degraded? || down?
  end

  private

  def prevent_mutation
    raise ActiveRecord::ReadOnlyRecord, "HealthEvent is immutable"
  end
end
