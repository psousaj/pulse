class ServiceNotification < ApplicationRecord
  belongs_to :account
  belongs_to :service
  belongs_to :notification_channel
end
