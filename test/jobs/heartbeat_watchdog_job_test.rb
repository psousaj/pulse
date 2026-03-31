require "test_helper"

class HeartbeatWatchdogJobTest < ActiveJob::TestCase
  setup do
    clear_enqueued_jobs
    clear_performed_jobs

    @account = create_account
    @service = create_service(account: @account)
  end

  test "opens incident for overdue heartbeat tokens" do
    overdue = HeartbeatToken.create!(
      account: @account,
      service: @service,
      token_digest: HeartbeatToken.digest("overdue-token"),
      expected_interval_seconds: 60,
      grace_seconds: 30,
      enabled: true,
      next_expected_at: 5.minutes.ago
    )

    HeartbeatToken.create!(
      account: @account,
      service: @service,
      token_digest: HeartbeatToken.digest("future-token"),
      expected_interval_seconds: 60,
      grace_seconds: 30,
      enabled: true,
      next_expected_at: 5.minutes.from_now
    )

    assert_difference("Incident.count", 1) do
      HeartbeatWatchdogJob.perform_now
    end

    incident = Incident.find_by!(service: @service, trigger_kind: "heartbeat_missed")
    assert_equal "open", incident.state
    assert_equal "down", incident.severity
    assert_equal "Heartbeat missed", incident.title
    assert_equal "down", @service.reload.current_status
    assert_equal overdue.account_id, incident.account_id
  end

  test "does not create duplicate active heartbeat incident" do
    HeartbeatToken.create!(
      account: @account,
      service: @service,
      token_digest: HeartbeatToken.digest("overdue-token"),
      expected_interval_seconds: 60,
      grace_seconds: 30,
      enabled: true,
      next_expected_at: 5.minutes.ago
    )

    Incident.create!(
      account: @account,
      service: @service,
      service_check: nil,
      state: "open",
      severity: "down",
      title: "Heartbeat missed",
      trigger_kind: "heartbeat_missed",
      opened_at: Time.current
    )

    assert_no_difference("Incident.count") do
      HeartbeatWatchdogJob.perform_now
    end
  end
end
