class HealthCheckType < ApplicationRecord
  has_many :service_checks, dependent: :restrict_with_exception

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :runner_class, presence: true
end
