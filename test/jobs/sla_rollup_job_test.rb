require "test_helper"

class SlaRollupJobTest < ActiveJob::TestCase
  setup do
    @account = create_account
    @service = create_service(account: @account)
    @check = create_service_check(service: @service)
  end

  test "creates rollups for all windows with computed percentages" do
    create_result(status: "up", duration_ms: 100)
    create_result(status: "up", duration_ms: 200)
    create_result(status: "degraded", duration_ms: 300)
    create_result(status: "down", duration_ms: 400)

    assert_difference("SlaRollup.count", 3) do
      SlaRollupJob.perform_now
    end

    rollup_24h = SlaRollup.find_by!(service: @service, window_key: "24h")
    assert_equal 4, rollup_24h.total_samples
    assert_equal 1, rollup_24h.failed_samples
    assert_equal 50.0, rollup_24h.uptime_pct
    assert_equal 25.0, rollup_24h.degraded_pct
    assert_equal 25.0, rollup_24h.down_pct
    assert_equal 250, rollup_24h.avg_latency_ms
    assert_equal 400, rollup_24h.p95_latency_ms
  end

  test "updates existing rollup rows with upsert" do
    create_result(status: "up", duration_ms: 120)
    SlaRollupJob.perform_now

    assert_no_difference("SlaRollup.count") do
      SlaRollupJob.perform_now
    end
  end

  private

  def create_result(status:, duration_ms:)
    now = Time.current
    CheckResult.create!(
      account: @account,
      service: @service,
      service_check: @check,
      scheduled_at: now,
      started_at: now,
      finished_at: now + 1.second,
      duration_ms: duration_ms,
      status: status,
      latency_breached: false,
      timed_out: false,
      metadata_json: {}
    )
  end
end