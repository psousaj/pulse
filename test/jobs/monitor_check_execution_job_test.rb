require "test_helper"

class MonitorCheckExecutionJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
    clear_performed_jobs

    @account = create_account
    @service = create_service(account: @account)
    @monitor = create_monitor(account: @account, service: @service)
  end

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "does nothing when monitor does not exist" do
    assert_no_difference("HealthEvent.count") do
      MonitorCheckExecutionJob.perform_now(-1)
    end
  end

  test "does nothing when monitor is disabled" do
    @monitor.update!(enabled: false)

    assert_no_difference("HealthEvent.count") do
      MonitorCheckExecutionJob.perform_now(@monitor.id)
    end
  end

  test "executes strategy and enqueues health event processing" do
    strategy = Class.new do
      def self.call(_monitor)
        {
          status: "up",
          checked_at: Time.current,
          latency_ms: 80,
          ttfb_ms: 80,
          metadata_json: { ok: true }
        }
      end
    end

    @monitor.update!(lease_token: "lease", lease_expires_at: 10.minutes.from_now)

    with_temporary_class_method(Monitoring::Strategies::Registry, :fetch, ->(_strategy) { strategy }) do
      assert_difference("HealthEvent.count", 1) do
        assert_enqueued_jobs 1, only: ProcessHealthEventJob do
          MonitorCheckExecutionJob.perform_now(@monitor.id, scheduled_at: 1.minute.ago.iso8601)
        end
      end
    end

    @monitor.reload
    assert_nil @monitor.lease_token
    assert_not_nil @monitor.next_run_at
  end
end
