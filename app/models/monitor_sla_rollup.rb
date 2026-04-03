class MonitorSlaRollup < ApplicationRecord
  belongs_to :account
  belongs_to :monitor, class_name: "PulseMonitor"

  validates :window_key, :window_start, :window_end, presence: true
end
