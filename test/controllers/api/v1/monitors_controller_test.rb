require "test_helper"

module Api
  module V1
    class MonitorsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @account = create_account
        @user = create_user(account: @account)
        @service = create_service(account: @account, name: "API Service", slug: "api-service")
        @monitor = create_monitor(account: @account, service: @service, name: "Primary Monitor", slug: "primary-monitor")
        @endpoint = create_integration_endpoint(account: @account, name: "Prod Zabbix")
        @binding = create_monitor_source_binding(monitor: @monitor, integration_endpoint: @endpoint, external_ref: "host-1")
        create_health_event(monitor: @monitor, monitor_source_binding: @binding, source: "integration", status: "down", error_message: "triggered")
        create_monitor_incident(monitor: @monitor, severity: "down")
        MonitorSlaRollup.create!(
          account: @account,
          monitor: @monitor,
          window_key: "24h",
          uptime_pct: 99.10,
          degraded_pct: 0.30,
          down_pct: 0.60,
          down_seconds: 518,
          degraded_seconds: 259,
          window_start: 24.hours.ago,
          window_end: Time.current
        )
      end

      test "returns unauthorized without bearer token" do
        get "/api/v1/monitors"

        assert_response :unauthorized
      end

      test "returns monitor inventory for valid token" do
        with_env("JWT_SECRET" => "jwt-test-secret") do
          get "/api/v1/monitors", headers: { "Authorization" => "Bearer #{issue_access_token}" }
        end

        assert_response :success
        monitor = response.parsed_body.fetch("monitors").find { |item| item["id"] == @monitor.id }

        assert_equal "Primary Monitor", monitor["name"]
        assert_equal "API Service", monitor["service_name"]
        assert_equal "integration", monitor.fetch("primary_binding")["kind"]
      end

      test "shows monitor detail payload" do
        with_env("JWT_SECRET" => "jwt-test-secret") do
          get "/api/v1/monitors/#{@monitor.id}", headers: { "Authorization" => "Bearer #{issue_access_token}" }
        end

        assert_response :success
        payload = response.parsed_body.fetch("monitor")

        assert_equal @monitor.id, payload["id"]
        assert_equal "Primary Monitor", payload["name"]
        assert_equal "host-1", payload.fetch("bindings").first["external_ref"]
        assert_equal "24h", payload.fetch("sla_rollups").first["window_key"]
        assert_equal "down", payload.fetch("recent_health_events").first["status"]
        assert_equal "down", payload.fetch("recent_incidents").first["severity"]
      end

      private

      def issue_access_token
        issue_api_access_token(account: @account, user: @user)
      end
    end
  end
end
