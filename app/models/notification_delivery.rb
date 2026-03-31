class NotificationDelivery < ApplicationRecord
  belongs_to :account
  belongs_to :incident
  belongs_to :notification_channel

  enum :status, {
    queued: "queued",
    sent: "sent",
    failed: "failed"
  }, default: :queued, validate: true
end
