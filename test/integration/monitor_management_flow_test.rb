require "test_helper"

class MonitorManagementFlowTest < ActionDispatch::IntegrationTest
  setup do
    @account = create_account
    @service = create_service(account: @account, name: "Payments", slug: "payments")
    @monitor = create_monitor(account: @account, service: @service, name: "Payments API", slug: "payments-api")
  end

  test "authenticated operator can view dashboard and create monitor resources" do
    sign_in

    MonitorSlaRollup.create!(
      account: @account,
      monitor: @monitor,
      window_key: "24h",
      uptime_pct: 99.9,
      degraded_pct: 0.05,
      down_pct: 0.05,
      down_seconds: 43,
      degraded_seconds: 43,
      window_start: 24.hours.ago,
      window_end: Time.current
    )

    get "/"

    assert_response :success
    assert_match "Primary operational assets", response.body
    assert_match "Payments API", response.body

    post "/monitors", params: {
      monitor: {
        service_id: @service.id,
        name: "Checkout latency",
        slug: "checkout-latency",
        strategy: "http_polling",
        interval_seconds: 90,
        enabled: "1",
        config_json_text: '{"url":"https://example.com/checkout","failure_threshold":3}'
      }
    }

    created_monitor = @account.monitors.find_by!(slug: "checkout-latency")
    assert_redirected_to monitor_path(created_monitor)

    post "/integration_endpoints", params: {
      integration_endpoint: {
        name: "Zabbix Prod",
        provider: "zabbix",
        enabled: "1",
        config_json_text: '{"region":"sa-east"}'
      }
    }

    endpoint = @account.integration_endpoints.find_by!(name: "Zabbix Prod")
    assert_redirected_to integration_endpoint_path(endpoint)

    post "/monitors/#{created_monitor.id}/bindings", params: {
      monitor_source_binding: {
        kind: "integration",
        role: "primary",
        integration_endpoint_id: endpoint.id,
        external_ref: "payments-host-1",
        enabled: "1",
        config_json_text: '{"status_map":{"PROBLEM":"down","OK":"up"}}'
      }
    }

    assert_redirected_to monitor_path(created_monitor)
    follow_redirect!

    assert_response :success
    assert_match "payments-host-1", response.body
  end

  private

  def sign_in
    account = @account

    with_temporary_class_method(Account, :first_or_create!, ->(*, **) { account }) do
      post "/auth/github/callback", env: { "omniauth.auth" => github_auth_hash(email: "owner@example.com", name: "Owner") }
    end

    assert_redirected_to "/"
  end
end