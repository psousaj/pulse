require "test_helper"

module Api
  module V1
    class ServicesControllerTest < ActionDispatch::IntegrationTest
      setup do
        @account = create_account
        @service = create_service(account: @account, name: "API Service", slug: "api-service")
        @monitor = create_monitor(account: @account, service: @service, name: "API Monitor", slug: "api-monitor")
        MonitorSlaRollup.create!(
          account: @account,
          monitor: @monitor,
          window_key: "24h",
          uptime_pct: 99.75,
          degraded_pct: 0.15,
          down_pct: 0.10,
          down_seconds: 86,
          degraded_seconds: 130,
          window_start: 24.hours.ago,
          window_end: Time.current
        )
      end

      test "returns unauthorized without bearer token" do
        get "/api/v1/services"

        assert_response :unauthorized
        assert_equal "missing_bearer_token", response.parsed_body["reason"]
      end

      test "returns unauthorized for invalid token" do
        with_keycloak_env do
          get "/api/v1/services", headers: { "Authorization" => "Bearer invalid" }
        end

        assert_response :unauthorized
        assert_equal "invalid_token", response.parsed_body["reason"]
      end

      test "returns forbidden when permission is missing" do
        with_keycloak_env do
          with_stubbed_keycloak_jwks do
            token = issue_keycloak_token(audience: ENV.fetch("KEYCLOAK_API_AUDIENCE"), account_slug: @account.slug, permissions: %w[incident.read])

            get "/api/v1/services", headers: { "Authorization" => "Bearer #{token}" }
          end
        end

        assert_response :forbidden
        assert_equal "insufficient_permissions", response.parsed_body["reason"]
      end

      test "returns unauthorized when account claim does not exist" do
        with_keycloak_env do
          with_stubbed_keycloak_jwks do
            token = issue_keycloak_token(audience: ENV.fetch("KEYCLOAK_API_AUDIENCE"), account_slug: "missing-account", permissions: %w[monitor.read])

          get "/api/v1/services", headers: { "Authorization" => "Bearer #{token}" }
          end
        end

        assert_response :unauthorized
        assert_equal "unknown_account", response.parsed_body["reason"]
      end

      test "returns services for valid token" do
        with_keycloak_env do
          with_stubbed_keycloak_jwks do
            token = issue_access_token

            get "/api/v1/services", headers: { "Authorization" => "Bearer #{token}" }
          end
        end

        assert_response :success
        service = response.parsed_body.fetch("services").find { |item| item["name"] == "API Service" }

        assert_equal 1, service["monitor_count"]
        assert_equal 0, service["down_monitors"]
      end

      test "shows monitors in service detail payload" do
        with_keycloak_env do
          with_stubbed_keycloak_jwks do
            get "/api/v1/services/#{@service.id}", headers: { "Authorization" => "Bearer #{issue_access_token}" }
          end
        end

        assert_response :success
        monitor = response.parsed_body.fetch("service").fetch("monitors").first

        assert_equal "API Monitor", monitor["name"]
        assert_equal "http_polling", monitor["strategy"]
        assert_equal "24h", monitor.fetch("sla_rollups").first["window_key"]
      end

      private

      def issue_access_token
        issue_keycloak_token(audience: ENV.fetch("KEYCLOAK_API_AUDIENCE"), account_slug: @account.slug, permissions: %w[monitor.read])
      end
    end
  end
end
