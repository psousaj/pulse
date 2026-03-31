require "test_helper"

module Monitoring
  class IncidentEngineTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      clear_enqueued_jobs
      clear_performed_jobs

      @account = create_account
      @service = create_service(account: @account)
      @service_check = create_service_check(service: @service)
    end

    teardown do
      clear_enqueued_jobs
      clear_performed_jobs
    end

    test "opens a down incident when failure threshold is reached" do
      @service_check.update!(consecutive_failures: 2, consecutive_successes: 0)
      check_result = create_check_result(service_check: @service_check, status: "down")

      assert_difference "Incident.count", 1 do
        assert_enqueued_jobs 1, only: NotificationDispatchJob do
          Monitoring::IncidentEngine.new(service_check: @service_check, check_result: check_result).call
        end
      end

      incident = Incident.order(:id).last
      assert_equal "open", incident.state
      assert_equal "down", incident.severity
      assert_equal "check_failure", incident.trigger_kind
      assert_equal "down", @service.reload.current_status
      assert IncidentEvent.exists?(incident: incident, event_type: "opened")
    end

    test "resolves active check incidents after success threshold" do
      incident = Incident.create!(
        account: @account,
        service: @service,
        service_check: @service_check,
        state: "open",
        severity: "down",
        title: "Service down",
        trigger_kind: "check_failure",
        opened_at: Time.current
      )

      @service_check.update!(consecutive_successes: 2, consecutive_failures: 0)
      check_result = create_check_result(service_check: @service_check, status: "up")

      assert_enqueued_jobs 1, only: NotificationDispatchJob do
        Monitoring::IncidentEngine.new(service_check: @service_check, check_result: check_result).call
      end

      incident.reload
      assert_equal "resolved", incident.state
      assert_equal "operational", @service.reload.current_status
      assert IncidentEvent.exists?(incident: incident, event_type: "resolved")
    end

    test "opens degraded incident after latency streak" do
      2.times do
        create_check_result(service_check: @service_check, status: "up", latency_breached: true)
      end
      current_result = create_check_result(service_check: @service_check, status: "degraded", latency_breached: true)

      assert_difference "Incident.count", 1 do
        Monitoring::IncidentEngine.new(service_check: @service_check, check_result: current_result).call
      end

      incident = Incident.order(:id).last
      assert_equal "degraded", incident.severity
      assert_equal "check_latency", incident.trigger_kind
      assert_equal "degraded", @service.reload.current_status
    end

    test "opens and resolves heartbeat incidents" do
      raw_token = "heartbeat-#{SecureRandom.hex(8)}"
      heartbeat = HeartbeatToken.create!(
        account: @account,
        service: @service,
        token_digest: HeartbeatToken.digest(raw_token),
        expected_interval_seconds: 60,
        grace_seconds: 30,
        enabled: true
      )

      assert_difference "Incident.count", 1 do
        assert_enqueued_jobs 1, only: NotificationDispatchJob do
          Monitoring::IncidentEngine.open_heartbeat_incident!(heartbeat)
        end
      end

      assert_no_difference "Incident.count" do
        Monitoring::IncidentEngine.open_heartbeat_incident!(heartbeat)
      end

      incident = Incident.where(service: @service, trigger_kind: "heartbeat_missed").order(:id).last
      assert_equal "open", incident.state

      assert_enqueued_jobs 1, only: NotificationDispatchJob do
        Monitoring::IncidentEngine.resolve_heartbeat_incidents!(heartbeat)
      end

      incident.reload
      assert_equal "resolved", incident.state
      assert_not_nil incident.resolved_at
    end
  end
end
