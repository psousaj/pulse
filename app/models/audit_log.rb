class AuditLog < ApplicationRecord
  belongs_to :account

  validates :source, :action, :target_type, :target_id, presence: true
end
