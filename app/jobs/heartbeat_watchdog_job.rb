class HeartbeatWatchdogJob < ApplicationJob
  queue_as :scheduler

  def perform
    now = Time.current

    HeartbeatToken.where(enabled: true)
      .where("next_expected_at IS NOT NULL AND next_expected_at < ?", now)
      .find_each do |heartbeat_token|
      Monitoring::IncidentEngine.open_heartbeat_incident!(heartbeat_token)
    end
  end
end
