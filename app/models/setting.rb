class Setting < ApplicationRecord
  belongs_to :account, optional: true

  validates :namespace, :key, presence: true
end
