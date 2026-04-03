class IntegrationEventIngress < ApplicationRecord
  belongs_to :account
  belongs_to :integration_endpoint
  belongs_to :monitor_source_binding, optional: true
  belongs_to :health_event, optional: true

  enum :status, {
    received: "received",
    accepted: "accepted",
    rejected: "rejected",
    duplicate: "duplicate"
  }, validate: true

  validates :provider, :idempotency_key, :received_at, presence: true
end
