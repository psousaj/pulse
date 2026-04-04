require "test_helper"

class MonitorManagementFlowTest < ActionDispatch::IntegrationTest
  setup do
    @account = create_account
    @service = create_service(account: @account, name: "Payments", slug: "payments")
    @monitor = create_monitor(account: @account, service: @service, name: "Payments API", slug: "payments-api")
  end

  test "authenticated operator can view dashboard and create monitor resources" do
    with_keycloak_login(account: @account, permissions: %w[monitor.read monitor.write incident.read admin]) do
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
      assert_match "See health, SLA drift and intake pressure", response.body
      assert_match "Payments", response.body

      get "/monitors/new"
      assert_response :success
      assert_match "New monitor", response.body

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

      get "/monitors/#{created_monitor.id}/bindings/new"
      assert_response :success
      assert_match "New binding for Checkout latency", response.body

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
  end

  test "authenticated operator can operate monitors endpoints and heartbeat bindings" do
    with_keycloak_login(account: @account, permissions: %w[monitor.read monitor.write incident.read admin]) do
      assert_enqueued_jobs 1, only: MonitorCheckExecutionJob do
        post "/monitors/#{@monitor.id}/run_now"
      end

      assert_redirected_to monitor_path(@monitor)

      patch "/monitors/#{@monitor.id}/disable"
      assert_redirected_to monitor_path(@monitor)
      assert_not @monitor.reload.enabled?
      assert_nil @monitor.next_run_at

      patch "/monitors/#{@monitor.id}/enable"
      assert_redirected_to monitor_path(@monitor)
      assert @monitor.reload.enabled?
      assert_not_nil @monitor.next_run_at

      endpoint = create_integration_endpoint(account: @account, name: "Ops Zabbix")
      previous_secret_digest = endpoint.secret_digest

      patch "/integration_endpoints/#{endpoint.id}/disable"
      assert_redirected_to integration_endpoint_path(endpoint)
      assert_not endpoint.reload.enabled?

      patch "/integration_endpoints/#{endpoint.id}/enable"
      assert_redirected_to integration_endpoint_path(endpoint)
      assert endpoint.reload.enabled?

      post "/integration_endpoints/#{endpoint.id}/rotate_secret"
      assert_redirected_to integration_endpoint_path(endpoint)
      assert_not_equal previous_secret_digest, endpoint.reload.secret_digest

      assert_difference -> { HeartbeatToken.count }, 1 do
        post "/monitors/#{@monitor.id}/bindings", params: {
          monitor_source_binding: {
            kind: "heartbeat",
            role: "corroborative",
            enabled: "1",
            config_json_text: "{}"
          }
        }
      end

      heartbeat_binding = @monitor.monitor_source_bindings.find_by!(kind: "heartbeat")
      heartbeat_token = HeartbeatToken.find_by!(account: @account, token_digest: heartbeat_binding.token_digest)

      assert_redirected_to monitor_path(@monitor)
      assert_equal @monitor.id, heartbeat_token.monitor_id
      assert_equal @service.id, heartbeat_token.service_id

      previous_digest = heartbeat_binding.token_digest
      post "/monitors/#{@monitor.id}/bindings/#{heartbeat_binding.id}/rotate_token"

      assert_redirected_to monitor_path(@monitor)
      assert_not_equal previous_digest, heartbeat_binding.reload.token_digest
      assert_equal heartbeat_binding.token_digest, heartbeat_token.reload.token_digest

      patch "/monitors/#{@monitor.id}/bindings/#{heartbeat_binding.id}/disable"
      assert_redirected_to monitor_path(@monitor)
      assert_not heartbeat_binding.reload.enabled?

      patch "/monitors/#{@monitor.id}/bindings/#{heartbeat_binding.id}/enable"
      assert_redirected_to monitor_path(@monitor)
      assert heartbeat_binding.reload.enabled?
    end
  end
end
