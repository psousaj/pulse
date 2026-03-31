require "test_helper"

class CheckExecutionJobTest < ActiveJob::TestCase
  setup do
    @account = create_account
    @service = create_service(account: @account)
    @service_check = create_service_check(service: @service)
  end

  test "does nothing when service check does not exist" do
    assert_no_difference("CheckResult.count") do
      CheckExecutionJob.perform_now(-1)
    end
  end

  test "does nothing when service check is disabled" do
    @service_check.update!(enabled: false)

    assert_no_difference("CheckResult.count") do
      CheckExecutionJob.perform_now(@service_check.id)
    end
  end

  test "executes monitoring service when check is enabled" do
    runner = Class.new do
      def self.call(_service_check)
        {
          status: "up",
          duration_ms: 80,
          http_status_code: 200,
          body_excerpt: "ok",
          json_path_result: nil,
          latency_breached: false,
          timed_out: false,
          metadata_json: {}
        }
      end
    end

    with_temporary_class_method(CheckRunners::Registry, :fetch, ->(_type_key) { runner }) do
      assert_difference("CheckResult.count", 1) do
        CheckExecutionJob.perform_now(@service_check.id, scheduled_at: 1.minute.ago.iso8601)
      end
    end

    @service_check.reload
    assert_equal 1, @service_check.consecutive_successes
    assert_equal 0, @service_check.consecutive_failures
  end
end
