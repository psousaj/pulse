class Incident < ApplicationRecord
  belongs_to :account
  belongs_to :service, optional: true
  belongs_to :monitor, class_name: "PulseMonitor", optional: true
  belongs_to :service_check, optional: true
  belongs_to :first_check_result, class_name: "CheckResult", optional: true
  belongs_to :last_check_result, class_name: "CheckResult", optional: true
  belongs_to :first_health_event, class_name: "HealthEvent", optional: true
  belongs_to :last_health_event, class_name: "HealthEvent", optional: true

  has_many :incident_events, dependent: :destroy
  has_many :notification_deliveries, dependent: :destroy

  enum :state, {
    open: "open",
    acknowledged: "acknowledged",
    resolved: "resolved"
  }, default: :open, validate: true

  enum :severity, {
    degraded: "degraded",
    down: "down"
  }, default: :down, validate: true

  scope :active, -> { where(state: %w[open acknowledged]) }

  def started_at
    opened_at
  end

  def started_at=(value)
    self.opened_at = value
  end

  def notification_service
    service || monitor&.service
  end

  def acknowledge!(actor = nil, user: nil)
    update!(
      state: :acknowledged,
      acknowledged_at: Time.current,
      acknowledged_by_ref: actor_reference_for(actor || user || Current.user)
    )
  end

  def resolve!(actor: nil, user: nil)
    resolved_time = Time.current
    update!(
      state: :resolved,
      resolved_at: resolved_time,
      resolved_by_ref: actor_reference_for(actor || user || Current.user),
      duration_seconds: duration_between(opened_at, resolved_time)
    )
  end

  private

  def duration_between(start_time, end_time)
    return nil if start_time.blank? || end_time.blank?

    [ (end_time - start_time).to_i, 0 ].max
  end

  def actor_reference_for(actor)
    return nil if actor.blank?
    return actor if actor.is_a?(String)

    actor.subject.presence || actor.email.presence || actor.username.presence || actor.id.to_s.presence || actor.to_s
  end
end
