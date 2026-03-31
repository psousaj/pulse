class NotificationChannel < ApplicationRecord
  belongs_to :account

  has_many :service_notifications, dependent: :destroy
  has_many :notification_deliveries, dependent: :destroy

  enum :kind, {
    discord: "discord",
    webhook: "webhook",
    email: "email"
  }, validate: true

  scope :defaults, -> { where(is_default: true) }

  validates :name, presence: true
  validates :kind, presence: true
end
