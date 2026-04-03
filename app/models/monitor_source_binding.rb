require "digest"

class MonitorSourceBinding < ApplicationRecord
  belongs_to :account
  belongs_to :monitor, class_name: "PulseMonitor"
  belongs_to :integration_endpoint, optional: true

  has_many :health_events, dependent: :nullify
  has_many :integration_event_ingresses, dependent: :nullify

  attr_reader :plain_token

  enum :kind, {
    internal: "internal",
    integration: "integration",
    heartbeat: "heartbeat"
  }, validate: true

  enum :role, {
    primary: "primary",
    corroborative: "corroborative"
  }, default: :corroborative, validate: true

  scope :enabled, -> { where(enabled: true) }

  validates :kind, presence: true
  validates :token_digest, uniqueness: true, allow_nil: true
  validate :single_primary_binding_per_monitor
  validate :integration_binding_requires_endpoint
  validate :heartbeat_binding_requires_token
  validate :heartbeat_binding_requires_service_context

  before_validation :sync_account_id
  before_validation :assign_token_digest, if: :heartbeat?

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def config
    config_json || {}
  end

  def heartbeat_token
    return nil unless heartbeat?
    return nil if account_id.blank? || token_digest.blank?

    HeartbeatToken.find_by(account_id: account_id, token_digest: token_digest)
  end

  def heartbeat_token_id
    heartbeat_token&.id
  end

  def activate!
    update!(enabled: true)
  end

  def deactivate!
    update!(enabled: false)
  end

  def external_status_map(raw_status)
    mappings = config.fetch("status_map", {})
    mapped = mappings[raw_status.to_s]
    mapped.presence || default_status_map(raw_status)
  end

  private

  def default_status_map(raw_status)
    case raw_status.to_s.upcase
    when "OK", "UP", "RECOVERY"
      "up"
    when "DEGRADED", "WARNING"
      "degraded"
    else
      "down"
    end
  end

  def sync_account_id
    self.account_id = monitor&.account_id if monitor.present?
    self.provider = integration_endpoint.provider if integration_endpoint.present? && provider.blank?
  end

  def assign_token_digest
    return if token_digest.present?

    @plain_token = SecureRandom.hex(24)
    self.token_digest = self.class.digest(@plain_token)
  end

  def single_primary_binding_per_monitor
    return unless primary?
    return if monitor.blank?

    existing = monitor.monitor_source_bindings.where(role: "primary")
    existing = existing.where.not(id: id) if persisted?
    errors.add(:role, "already has a primary binding for this monitor") if existing.exists?
  end

  def integration_binding_requires_endpoint
    return unless integration?

    errors.add(:integration_endpoint, "must exist for integration bindings") if integration_endpoint.blank?
    errors.add(:external_ref, "can't be blank") if external_ref.blank?
  end

  def heartbeat_binding_requires_token
    return unless heartbeat?

    errors.add(:token_digest, "can't be blank") if token_digest.blank?
  end

  def heartbeat_binding_requires_service_context
    return unless heartbeat?

    errors.add(:monitor, "must belong to a service for heartbeat bindings") if monitor&.service.blank?
  end
end
