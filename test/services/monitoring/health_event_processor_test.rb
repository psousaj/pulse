require "test_helper"

module Monitoring
  class HealthEventProcessorTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      clear_enqueued_jobs
      clear_performed_jobs

      @account = create_account
      @service = create_service(account: @account)
      @monitor = create_monitor(
        account: @account,
        service: @service,
        config_json: { "url" => "https://example.com/health", "failure_threshold" => 2, "success_threshold" => 2 }
      )
    end

    teardown do
      clear_enqueued_jobs
      clear_performed_jobs
    end

    test "opens an incident after the configured failure threshold" do
      create_health_event(monitor: @monitor, service: @service, source: "internal", status: "down", checked_at: 2.minutes.ago)
      event = create_health_event(monitor: @monitor, service: @service, source: "internal", status: "down", checked_at: 1.minute.ago)

      assert_difference("Incident.count", 1) do
        assert_enqueued_jobs 1, only: NotificationDispatchJob do
          ProcessHealthEventJob.perform_now(event.id)
        end
      end

      incident = Incident.order(:id).last
      assert_equal @monitor, incident.monitor
      assert_equal event, incident.last_health_event
      assert_equal "down", incident.severity
      assert_equal "down", @monitor.reload.current_status
      assert_equal "down", @service.reload.current_status
    end

    test "resolves an open incident after the configured success threshold" do
      incident = create_monitor_incident(monitor: @monitor, service: @service, severity: "down", opened_at: 10.minutes.ago)
      create_health_event(monitor: @monitor, service: @service, source: "internal", status: "up", checked_at: 2.minutes.ago)
      event = create_health_event(monitor: @monitor, service: @service, source: "internal", status: "up", checked_at: 1.minute.ago)

      assert_enqueued_jobs 1, only: NotificationDispatchJob do
        ProcessHealthEventJob.perform_now(event.id)
      end

      incident.reload
      assert_equal "resolved", incident.state
      assert_not_nil incident.resolved_at
      assert_operator incident.duration_seconds, :>, 0
      assert_equal "up", @monitor.reload.current_status
      assert_equal "operational", @service.reload.current_status
    end

    test "changes incident severity without sending another notification" do
      incident = create_monitor_incident(monitor: @monitor, service: @service, severity: "degraded", opened_at: 5.minutes.ago)
      event = create_health_event(monitor: @monitor, service: @service, source: "integration", status: "down", checked_at: Time.current)

      assert_no_enqueued_jobs only: NotificationDispatchJob do
        ProcessHealthEventJob.perform_now(event.id)
      end

      incident.reload
      assert_equal "down", incident.severity
      assert IncidentEvent.exists?(incident: incident, event_type: "severity_changed")
      assert_equal "down", @monitor.reload.current_status
    end
  end
end
