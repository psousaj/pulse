class SlaRollup < ApplicationRecord
  belongs_to :account
  belongs_to :service

  validates :window_key, presence: true
end
