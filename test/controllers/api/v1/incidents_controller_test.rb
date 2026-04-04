require "test_helper"

module Api
  module V1
    class IncidentsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @account = create_account
        @service = create_service(account: @account, name: "API Service", slug: "api-service")
        @monitor = create_monitor(account: @account, service: @service, name: "API Monitor", slug: "api-monitor")
      end

      test "returns unauthorized without bearer token" do
        get "/api/v1/incidents"

        assert_response :unauthorized
        assert_equal "missing_bearer_token", response.parsed_body["reason"]
      end

      test "returns incidents from current account only" do
        incident_a = create_incident(account: @account, service: @service, monitor: @monitor, title: "Incident A")
        create_incident(account: @account, service: @service, monitor: @monitor, title: "Incident B")

        other_account = create_account
        other_service = create_service(account: other_account)
        other_monitor = create_monitor(account: other_account, service: other_service)
        create_incident(account: other_account, service: other_service, monitor: other_monitor, title: "External Incident")

        with_keycloak_env do
          with_stubbed_keycloak_jwks do
            get "/api/v1/incidents", headers: { "Authorization" => "Bearer #{issue_access_token}" }
          end
        end

        assert_response :success
        incidents = response.parsed_body.fetch("incidents")
        ids = incidents.map { |item| item["id"] }
        titles = incidents.map { |item| item["title"] }

        assert_includes ids, incident_a.id
        assert_includes titles, "Incident B"
        assert_not_includes titles, "External Incident"
      end

      test "shows incident payload for current account" do
        incident = create_incident(account: @account, service: @service, monitor: @monitor, title: "Incident detail")

        with_keycloak_env do
          with_stubbed_keycloak_jwks do
            get "/api/v1/incidents/#{incident.id}", headers: { "Authorization" => "Bearer #{issue_access_token}" }
          end
        end

        assert_response :success
        payload = response.parsed_body.fetch("incident")
        assert_equal incident.id, payload["id"]
        assert_equal "Incident detail", payload["title"]
        assert_equal "open", payload["state"]
        assert_equal @monitor.id, payload["monitor_id"]
        assert_equal "API Monitor", payload["monitor_name"]
      end

      test "returns not found when incident belongs to another account" do
        other_account = create_account
        other_service = create_service(account: other_account)
        other_monitor = create_monitor(account: other_account, service: other_service)
        external_incident = create_incident(
          account: other_account,
          service: other_service,
          monitor: other_monitor,
          title: "External Incident"
        )

        with_keycloak_env do
          with_stubbed_keycloak_jwks do
            get "/api/v1/incidents/#{external_incident.id}", headers: { "Authorization" => "Bearer #{issue_access_token}" }
          end
        end

        assert_response :not_found
      end

      private

      def create_incident(account:, service:, monitor:, title:)
        Incident.create!(
          account: account,
          service: service,
          monitor: monitor,
          state: "open",
          severity: "down",
          title: title,
          trigger_kind: "check_failure",
          opened_at: Time.current
        )
      end

      def issue_access_token
        issue_keycloak_token(audience: ENV.fetch("KEYCLOAK_API_AUDIENCE"), account_slug: @account.slug, permissions: %w[incident.read])
      end
    end
  end
end
