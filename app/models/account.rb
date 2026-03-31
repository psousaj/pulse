class Account < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :service_checks, dependent: :delete_all
  has_many :check_results, dependent: :delete_all
  has_many :incidents, dependent: :delete_all
  has_many :heartbeat_tokens, dependent: :delete_all
  has_many :notification_channels, dependent: :destroy
  has_many :api_clients, dependent: :delete_all
  has_many :settings, dependent: :destroy
  has_many :audit_logs, dependent: :delete_all

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :default_alert_interval_minutes, numericality: { greater_than: 0 }
end
