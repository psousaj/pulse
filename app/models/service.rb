class Service < ApplicationRecord
  belongs_to :account

  has_many :monitors, class_name: "PulseMonitor", dependent: :nullify
  has_many :service_checks, dependent: :destroy
  has_many :check_results, dependent: :delete_all
  has_many :incidents, dependent: :delete_all
  has_many :heartbeat_tokens, dependent: :destroy
  has_many :service_notifications, dependent: :destroy

  enum :visibility, {
    private: "private",
    public: "public"
  }, default: :private, prefix: true, validate: true

  enum :current_status, {
    operational: "operational",
    degraded: "degraded",
    down: "down"
  }, default: :operational, validate: true

  scope :publicly_visible, -> { where(visibility: "public") }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :account_id }

  def in_maintenance_window?(at: Time.current)
    return false if maintenance_starts_at.blank? || maintenance_ends_at.blank?

    at.between?(maintenance_starts_at, maintenance_ends_at)
  end
end
