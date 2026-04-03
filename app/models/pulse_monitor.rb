class PulseMonitor < ApplicationRecord
  self.table_name = "monitors"

  INTERNAL_STRATEGIES = %w[http_polling synthetic_browser].freeze
  STRATEGIES = (INTERNAL_STRATEGIES + [ "event_only" ]).freeze

  belongs_to :account
  belongs_to :service, optional: true

  has_many :health_events, foreign_key: :monitor_id, dependent: :delete_all
  has_many :incidents, foreign_key: :monitor_id, dependent: :nullify
  has_many :monitor_sla_rollups, foreign_key: :monitor_id, dependent: :delete_all
  has_many :monitor_source_bindings, foreign_key: :monitor_id, dependent: :destroy

  enum :current_status, {
    up: "up",
    degraded: "degraded",
    down: "down"
  }, default: :up, validate: true

  scope :enabled, -> { where(enabled: true) }
  scope :internal_checks, -> { where(strategy: INTERNAL_STRATEGIES) }
  scope :due, ->(at = Time.current) { enabled.internal_checks.where("next_run_at IS NULL OR next_run_at <= ?", at) }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :account_id }
  validates :strategy, inclusion: { in: STRATEGIES }
  validates :interval_seconds, numericality: { greater_than: 0 }, allow_nil: true

  before_validation :set_initial_next_run_at, on: :create

  def config
    config_json || {}
  end

  def internal_strategy?
    INTERNAL_STRATEGIES.include?(strategy)
  end

  def primary_binding
    monitor_source_bindings.enabled.primary.order(:id).first
  end

  def runnable_manually?
    enabled? && internal_strategy?
  end

  def authoritative_without_binding?(source:)
    binding = primary_binding
    return true if binding.blank?

    source.to_s == binding.kind
  end

  def activate!
    attrs = {
      enabled: true,
      lease_token: nil,
      lease_expires_at: nil
    }
    attrs[:next_run_at] = Time.current if internal_strategy? && next_run_at.blank?
    update!(attrs)
  end

  def deactivate!
    attrs = {
      enabled: false,
      lease_token: nil,
      lease_expires_at: nil
    }
    attrs[:next_run_at] = nil if internal_strategy?
    update!(attrs)
  end

  def acquire_lease!(ttl_seconds: 30)
    now = Time.current
    token = SecureRandom.hex(8)
    updated = self.class.where(id: id)
      .where("lease_expires_at IS NULL OR lease_expires_at < ?", now)
      .update_all(lease_token: token, lease_expires_at: now + ttl_seconds)

    updated == 1
  end

  def release_lease!
    update_columns(lease_token: nil, lease_expires_at: nil)
  end

  def schedule_next_run!(from: Time.current)
    return unless interval_seconds.present?

    update_columns(last_run_at: from, next_run_at: from + interval_seconds)
  end

  def failure_threshold
    positive_integer_from_config("failure_threshold", default: 2)
  end

  def success_threshold
    positive_integer_from_config("success_threshold", default: 2)
  end

  private

  def positive_integer_from_config(key, default:)
    value = config[key].to_i
    value.positive? ? value : default
  end

  def set_initial_next_run_at
    return unless internal_strategy?
    return if interval_seconds.blank?

    self.next_run_at ||= Time.current
  end
end
