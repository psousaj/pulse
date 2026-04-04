require "test_helper"

module Api
  module V1
    class MonitorSlaRollupsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @account = create_account
        @service = create_service(account: @account)
        @monitor = create_monitor(account: @account, service: @service, name: "SLA Monitor", slug: "sla-monitor")
        @rollup = MonitorSlaRollup.create!(
          account: @account,
          monitor: @monitor,
          window_key: "24h",
          uptime_pct: 98.5,
          degraded_pct: 0.5,
          down_pct: 1.0,
          down_seconds: 864,
          degraded_seconds: 432,
          window_start: 24.hours.ago,
          window_end: Time.current
        )

        other_account = create_account
        other_monitor = create_monitor(account: other_account, service: create_service(account: other_account))
        MonitorSlaRollup.create!(
          account: other_account,
          monitor: other_monitor,
          window_key: "24h",
          uptime_pct: 90.0,
          degraded_pct: 2.0,
          down_pct: 8.0,
          down_seconds: 6912,
          degraded_seconds: 1728,
          window_start: 24.hours.ago,
          window_end: Time.current
        )
      end

      test "returns current account rollups only" do
        with_keycloak_env do
          with_stubbed_keycloak_jwks do
            get "/api/v1/monitor_sla_rollups", headers: { "Authorization" => "Bearer #{issue_access_token}" }
          end
        end

        assert_response :success
        rollups = response.parsed_body.fetch("monitor_sla_rollups")

        assert_equal [ @rollup.id ], rollups.map { |item| item["id"] }
        assert_equal "SLA Monitor", rollups.first["monitor_name"]
      end

      test "filters by monitor" do
        with_keycloak_env do
          with_stubbed_keycloak_jwks do
            get "/api/v1/monitor_sla_rollups", params: { monitor_id: @monitor.id }, headers: { "Authorization" => "Bearer #{issue_access_token}" }
          end
        end

        assert_response :success
        assert_equal 1, response.parsed_body.fetch("monitor_sla_rollups").size
      end

      private

      def issue_access_token
        issue_keycloak_token(audience: ENV.fetch("KEYCLOAK_API_AUDIENCE"), account_slug: @account.slug, permissions: %w[monitor.read])
      end
    end
  end
end
