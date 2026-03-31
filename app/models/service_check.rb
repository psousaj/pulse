class ServiceCheck < ApplicationRecord
  INTERVALS = [ 30, 60, 300 ].freeze

  belongs_to :account
  belongs_to :service
  belongs_to :health_check_type

  has_many :check_results, dependent: :delete_all
  has_many :incidents, dependent: :nullify

  scope :enabled, -> { where(enabled: true) }
  scope :due, ->(at = Time.current) { enabled.where("next_run_at IS NULL OR next_run_at <= ?", at) }

  validates :name, presence: true
  validates :interval_seconds, inclusion: { in: INTERVALS }
  validates :timeout_ms, numericality: { greater_than: 0 }

  before_validation :set_initial_next_run_at, on: :create

  def config
    config_json || {}
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
    update_columns(last_run_at: from, next_run_at: from + interval_seconds)
  end

  private

  def set_initial_next_run_at
    self.next_run_at ||= Time.current
  end
end
