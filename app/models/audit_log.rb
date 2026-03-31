class AuditLog < ApplicationRecord
  belongs_to :account
  belongs_to :user, optional: true

  validates :source, :action, :target_type, :target_id, presence: true
end
