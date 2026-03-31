require "test_helper"

module Monitoring
  class CheckExecutionServiceTest < ActiveSupport::TestCase
    setup do
      @account = create_account
      @service = create_service(account: @account)
      @service_check = create_service_check(service: @service)
    end

    test "persists successful runner payload and updates counters" do
      @service_check.update!(consecutive_failures: 2, consecutive_successes: 0, lease_token: "lease", lease_expires_at: 10.minutes.from_now)

      successful_runner = Class.new do
        def self.call(_service_check)
          {
            status: "up",
            duration_ms: 123,
            http_status_code: 200,
            body_excerpt: "healthy",
            json_path_result: nil,
            latency_breached: false,
            timed_out: false,
            metadata_json: { source: "test" }
          }
        end
      end

      scheduled_at = 2.minutes.ago.iso8601
      result = nil

      with_temporary_class_method(CheckRunners::Registry, :fetch, ->(_type_key) { successful_runner }) do
        result = Monitoring::CheckExecutionService.new(service_check: @service_check, scheduled_at: scheduled_at).call
      end

      assert_equal "up", result.status
      assert_equal 123, result.duration_ms
      assert_equal 200, result.http_status_code
      assert_equal "healthy", result.body_excerpt
      assert_equal Time.iso8601(scheduled_at).to_i, result.scheduled_at.to_i
      assert_equal "test", result.metadata_json["source"]

      @service_check.reload
      assert_equal 0, @service_check.consecutive_failures
      assert_equal 1, @service_check.consecutive_successes
      assert_nil @service_check.lease_token
      assert_nil @service_check.lease_expires_at
      assert_not_nil @service_check.next_run_at
    end

    test "persists error payload and increments failure counters when runner raises" do
      @service_check.update!(consecutive_failures: 1, consecutive_successes: 4, lease_token: "lease", lease_expires_at: 10.minutes.from_now)

      failing_runner = Class.new do
        def self.call(_service_check)
          raise StandardError, "runner exploded"
        end
      end

      result = nil

      with_temporary_class_method(CheckRunners::Registry, :fetch, ->(_type_key) { failing_runner }) do
        result = Monitoring::CheckExecutionService.new(service_check: @service_check, scheduled_at: "not-an-iso-time").call
      end

      assert_equal "error", result.status
      assert_nil result.scheduled_at
      assert_equal "StandardError", result.error_class
      assert_equal "runner exploded", result.error_message
      assert_equal "execution_exception", result.metadata_json["reason"]

      @service_check.reload
      assert_equal 2, @service_check.consecutive_failures
      assert_equal 0, @service_check.consecutive_successes
      assert_nil @service_check.lease_token
      assert_nil @service_check.lease_expires_at
      assert_not_nil @service_check.next_run_at
    end
  end
end