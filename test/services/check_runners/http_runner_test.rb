require "test_helper"

module CheckRunners
  class HttpRunnerTest < ActiveSupport::TestCase
    FakeResponse = Struct.new(:code, :body)

    class FakeHttpClient
      attr_accessor :use_ssl, :open_timeout, :read_timeout
      attr_reader :last_request

      def initialize(response: nil, error: nil)
        @response = response
        @error = error
      end

      def request(request)
        @last_request = request
        raise @error if @error

        @response
      end
    end

    setup do
      @account = create_account
      @service = create_service(account: @account)
    end

    test "returns up for expected status and body" do
      service_check = create_http_service_check(
        config_json: {
          "url" => "https://example.com/health",
          "expected_status" => 200,
          "body_contains" => "healthy",
          "auth" => { "type" => "bearer", "token" => "secret-token" }
        }
      )

      fake_http = FakeHttpClient.new(response: FakeResponse.new("200", "healthy:true"))

      result = nil
      with_temporary_class_method(Net::HTTP, :new, ->(_host, _port) { fake_http }) do
        result = CheckRunners::HttpRunner.call(service_check)
      end

      assert_equal "up", result[:status]
      assert_equal 200, result[:http_status_code]
      assert_equal "Bearer secret-token", fake_http.last_request["Authorization"]
      assert_equal false, result[:timed_out]
      assert_equal [], result[:metadata_json][:failure_reasons]
    end

    test "returns down when status is unexpected" do
      service_check = create_http_service_check(
        config_json: {
          "url" => "https://example.com/health",
          "expected_status" => [ 200 ]
        }
      )

      fake_http = FakeHttpClient.new(response: FakeResponse.new("503", "unavailable"))

      result = nil
      with_temporary_class_method(Net::HTTP, :new, ->(_host, _port) { fake_http }) do
        result = CheckRunners::HttpRunner.call(service_check)
      end

      assert_equal "down", result[:status]
      assert_equal 503, result[:http_status_code]
      assert_includes result[:metadata_json][:failure_reasons], "unexpected_status"
    end

    test "marks timeout as down with timed_out flag" do
      service_check = create_http_service_check(
        config_json: { "url" => "https://example.com/health" }
      )

      fake_http = FakeHttpClient.new(error: Net::ReadTimeout.new)

      result = nil
      with_temporary_class_method(Net::HTTP, :new, ->(_host, _port) { fake_http }) do
        result = CheckRunners::HttpRunner.call(service_check)
      end

      assert_equal "down", result[:status]
      assert_equal true, result[:timed_out]
      assert_equal "Net::ReadTimeout", result[:error_class]
      assert_equal "timeout", result[:metadata_json][:reason]
    end

    test "returns degraded when latency breaches threshold" do
      service_check = create_http_service_check(
        config_json: { "url" => "https://example.com/health" },
        max_latency_ms: -1
      )

      fake_http = FakeHttpClient.new(response: FakeResponse.new("200", "ok"))

      result = nil
      with_temporary_class_method(Net::HTTP, :new, ->(_host, _port) { fake_http }) do
        result = CheckRunners::HttpRunner.call(service_check)
      end

      assert_equal "degraded", result[:status]
      assert_equal true, result[:latency_breached]
      assert_operator result[:duration_ms], :>=, 0
    end

    private

    def create_http_service_check(config_json:, max_latency_ms: nil)
      check = create_service_check(service: @service, config_json: config_json)
      check.update!(max_latency_ms: max_latency_ms)
      check
    end
  end
end