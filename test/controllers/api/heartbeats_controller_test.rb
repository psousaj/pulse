require "test_helper"

module Api
  class HeartbeatsControllerTest < ActionDispatch::IntegrationTest
    setup do
      Rails.cache.clear
      @account = create_account
      @service = create_service(account: @account)
      @raw_token = "heartbeat-#{SecureRandom.hex(8)}"
      @heartbeat = HeartbeatToken.create!(
        account: @account,
        service: @service,
        token_digest: HeartbeatToken.digest(@raw_token),
        expected_interval_seconds: 60,
        grace_seconds: 30,
        enabled: true
      )
    end

    teardown do
      Rails.cache.clear
    end

    test "returns not found for unknown token" do
      post "/api/heartbeat/unknown"

      assert_response :not_found
      assert_equal "heartbeat_not_found", response.parsed_body["error"]
    end

    test "accepts heartbeat, updates timestamps, and resolves heartbeat incidents" do
      incident = Incident.create!(
        account: @account,
        service: @service,
        service_check: nil,
        state: "open",
        severity: "down",
        title: "Heartbeat missed",
        trigger_kind: "heartbeat_missed",
        opened_at: Time.current
      )

      post "/api/heartbeat/#{@raw_token}"

      assert_response :accepted
      assert_equal "accepted", response.parsed_body["status"]
      assert_equal @service.slug, response.parsed_body["service"]

      @heartbeat.reload
      assert_not_nil @heartbeat.last_heartbeat_at
      assert_not_nil @heartbeat.next_expected_at
      assert_operator @heartbeat.next_expected_at, :>, @heartbeat.last_heartbeat_at

      incident.reload
      assert_equal "resolved", incident.state
      assert_not_nil incident.resolved_at
    end

    test "enforces rate limit by account setting" do
      Setting.create!(
        account: @account,
        namespace: "heartbeat",
        key: "rate_limit_per_minute",
        value_json: { "value" => 1 }
      )

      original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new

      begin
        post "/api/heartbeat/#{@raw_token}"
        assert_response :accepted

        post "/api/heartbeat/#{@raw_token}"
        assert_response :too_many_requests
        assert_equal "rate_limited", response.parsed_body["error"]
      ensure
        Rails.cache = original_cache
      end
    end
  end
end
