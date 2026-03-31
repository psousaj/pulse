class Incident < ApplicationRecord
  belongs_to :account
  belongs_to :service
  belongs_to :service_check, optional: true
  belongs_to :acknowledged_by_user, class_name: "User", optional: true
  belongs_to :resolved_by_user, class_name: "User", optional: true
  belongs_to :first_check_result, class_name: "CheckResult", optional: true
  belongs_to :last_check_result, class_name: "CheckResult", optional: true

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

  def acknowledge!(user)
    update!(state: :acknowledged, acknowledged_at: Time.current, acknowledged_by_user: user)
  end

  def resolve!(user: nil)
    update!(state: :resolved, resolved_at: Time.current, resolved_by_user: user)
  end
end
