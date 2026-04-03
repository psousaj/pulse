require "test_helper"

class MonitorSlaRollupJobTest < ActiveJob::TestCase
  setup do
    @account = create_account
    @service = create_service(account: @account)
    @monitor = create_monitor(account: @account, service: @service)
  end

  test "creates rollups from incident duration and severity transitions" do
    incident = create_monitor_incident(monitor: @monitor, service: @service, severity: "degraded", opened_at: 3.hours.ago)
    IncidentEvent.create!(
      account: @account,
      incident: incident,
      event_type: "opened",
      actor_type: "system",
      to_state: "open",
      payload_json: { "severity" => "degraded", "checked_at" => 3.hours.ago.iso8601 }
    )
    IncidentEvent.create!(
      account: @account,
      incident: incident,
      event_type: "severity_changed",
      actor_type: "system",
      from_state: "degraded",
      to_state: "down",
      payload_json: { "checked_at" => 2.hours.ago.iso8601 }
    )
    incident.update!(resolved_at: 1.hour.ago, state: "resolved", severity: "down", duration_seconds: 7200)
    IncidentEvent.create!(
      account: @account,
      incident: incident,
      event_type: "resolved",
      actor_type: "system",
      from_state: "open",
      to_state: "resolved",
      payload_json: { "checked_at" => 1.hour.ago.iso8601 }
    )

    assert_difference("MonitorSlaRollup.count", 3) do
      MonitorSlaRollupJob.perform_now
    end

    rollup = MonitorSlaRollup.find_by!(monitor: @monitor, window_key: "24h")
    assert_in_delta 3600, rollup.degraded_seconds, 1
    assert_in_delta 3600, rollup.down_seconds, 1
    assert_operator rollup.uptime_pct.to_f, :<, 100.0
    assert_operator rollup.degraded_pct.to_f, :>, 0.0
    assert_operator rollup.down_pct.to_f, :>, 0.0
  end
end
