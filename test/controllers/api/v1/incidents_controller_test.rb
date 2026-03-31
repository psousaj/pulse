require "test_helper"

module Api
  module V1
    class IncidentsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @account = create_account
        @user = create_user(account: @account)
        @service = create_service(account: @account, name: "API Service", slug: "api-service")
        @service_check = create_service_check(service: @service)
      end

      test "returns unauthorized without bearer token" do
        get "/api/v1/incidents"

        assert_response :unauthorized
        assert_equal "missing_bearer_token", response.parsed_body["reason"]
      end

      test "returns incidents from current account only" do
        incident_a = create_incident(account: @account, service: @service, service_check: @service_check, title: "Incident A")
        create_incident(account: @account, service: @service, service_check: @service_check, title: "Incident B")

        other_account = create_account
        other_service = create_service(account: other_account)
        other_check = create_service_check(service: other_service)
        create_incident(account: other_account, service: other_service, service_check: other_check, title: "External Incident")

        with_env("JWT_SECRET" => "jwt-test-secret") do
          get "/api/v1/incidents", headers: { "Authorization" => "Bearer #{issue_access_token}" }
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
        incident = create_incident(account: @account, service: @service, service_check: @service_check, title: "Incident detail")

        with_env("JWT_SECRET" => "jwt-test-secret") do
          get "/api/v1/incidents/#{incident.id}", headers: { "Authorization" => "Bearer #{issue_access_token}" }
        end

        assert_response :success
        payload = response.parsed_body.fetch("incident")
        assert_equal incident.id, payload["id"]
        assert_equal "Incident detail", payload["title"]
        assert_equal "open", payload["state"]
      end

      private

      def create_incident(account:, service:, service_check:, title:)
        Incident.create!(
          account: account,
          service: service,
          service_check: service_check,
          state: "open",
          severity: "down",
          title: title,
          trigger_kind: "check_failure",
          opened_at: Time.current
        )
      end

      def issue_access_token
        api_client = ApiClient.create!(account: @account, name: "tests-client")
        Api::TokenIssuer.new(secret: "jwt-test-secret").issue!(user: @user, api_client: api_client)[:access_token]
      end
    end
  end
end