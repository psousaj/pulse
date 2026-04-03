require "test_helper"

module Integrations
  class ZabbixEventsControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    setup do
      clear_enqueued_jobs
      clear_performed_jobs

      @account = create_account
      @service = create_service(account: @account)
      @monitor = create_monitor(account: @account, service: @service, strategy: "event_only", interval_seconds: nil, config_json: {})
      @endpoint = create_integration_endpoint(account: @account, provider: "zabbix")
      @binding = create_monitor_source_binding(
        monitor: @monitor,
        integration_endpoint: @endpoint,
        kind: "integration",
        role: "primary",
        external_ref: "cliente-api"
      )
    end

    teardown do
      clear_enqueued_jobs
      clear_performed_jobs
    end

    test "accepts a zabbix event, persists ingress and enqueues processing" do
      payload = {
        event_id: "zbx-1",
        host: "cliente-api",
        status: "PROBLEM",
        trigger: "HTTP DOWN",
        timestamp: Time.current.to_i
      }

      assert_difference("IntegrationEventIngress.count", 1) do
        assert_difference("HealthEvent.count", 1) do
          assert_enqueued_jobs 1, only: ProcessHealthEventJob do
            post "/integrations/zabbix/events",
              params: payload,
              as: :json,
              headers: { "Authorization" => "Bearer #{@endpoint.plain_secret}" }
          end
        end
      end

      assert_response :accepted
      assert_equal "accepted", response.parsed_body["status"]

      ingress = IntegrationEventIngress.order(:id).last
      event = HealthEvent.order(:id).last
      assert_equal "accepted", ingress.status
      assert_equal event, ingress.health_event
      assert_equal @binding, event.monitor_source_binding
      assert_equal "down", event.status
      assert event.authoritative?
    end

    test "rejects authenticated requests when no monitor binding exists" do
      payload = {
        event_id: "zbx-2",
        host: "unknown-host",
        status: "PROBLEM",
        trigger: "HTTP DOWN",
        timestamp: Time.current.to_i
      }

      assert_difference("IntegrationEventIngress.count", 1) do
        assert_no_difference("HealthEvent.count") do
          post "/integrations/zabbix/events",
            params: payload,
            as: :json,
            headers: { "Authorization" => "Bearer #{@endpoint.plain_secret}" }
        end
      end

      assert_response :unprocessable_entity
      assert_equal "monitor_binding_not_found", response.parsed_body["error"]
      assert_equal "rejected", IntegrationEventIngress.order(:id).last.status
    end

    test "treats duplicate provider events as accepted duplicates" do
      payload = {
        event_id: "zbx-3",
        host: "cliente-api",
        status: "PROBLEM",
        trigger: "HTTP DOWN",
        timestamp: Time.current.to_i
      }

      post "/integrations/zabbix/events",
        params: payload,
        as: :json,
        headers: { "Authorization" => "Bearer #{@endpoint.plain_secret}" }

      assert_no_difference("IntegrationEventIngress.count") do
        assert_no_difference("HealthEvent.count") do
          post "/integrations/zabbix/events",
            params: payload,
            as: :json,
            headers: { "Authorization" => "Bearer #{@endpoint.plain_secret}" }
        end
      end

      assert_response :accepted
      assert_equal true, response.parsed_body["duplicate"]
    end
  end
end
