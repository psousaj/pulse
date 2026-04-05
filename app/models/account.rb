class Account < ApplicationRecord
  has_many :services, dependent: :destroy
  has_many :monitors, class_name: "PulseMonitor", dependent: :destroy
  has_many :service_checks, dependent: :delete_all
  has_many :check_results, dependent: :delete_all
  has_many :health_events, dependent: :delete_all
  has_many :incidents, dependent: :delete_all
  has_many :heartbeat_tokens, dependent: :delete_all
  has_many :integration_endpoints, dependent: :destroy
  has_many :monitor_source_bindings, dependent: :destroy
  has_many :integration_event_ingresses, dependent: :delete_all
  has_many :monitor_sla_rollups, dependent: :delete_all
  has_many :notification_channels, dependent: :destroy
  has_many :settings, dependent: :destroy
  has_many :audit_logs, dependent: :delete_all

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :default_alert_interval_minutes, numericality: { greater_than: 0 }
end
