class IncidentEvent < ApplicationRecord
  belongs_to :account
  belongs_to :incident

  validates :event_type, presence: true
  validates :actor_type, presence: true
end
