require "base64"
require "json"
require "jsonpath"
require "net/http"
require "uri"

module CheckRunners
  class HttpRunner < BaseRunner
    MAX_BODY_EXCERPT = 500

    def call
      started = monotonic_now
      response = perform_request
      duration_ms = elapsed_ms_since(started)

      evaluate_response(response, duration_ms)
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      build_result(
        status: "down",
        duration_ms: nil,
        timed_out: true,
        error_class: e.class.name,
        error_message: e.message,
        metadata: { reason: "timeout" }
      )
    rescue StandardError => e
      build_result(
        status: "error",
        duration_ms: nil,
        error_class: e.class.name,
        error_message: e.message,
        metadata: { reason: "exception" }
      )
    end

    private

    def perform_request
      url = URI.parse(config.fetch("url"))
      request_method = config.fetch("method", "GET").upcase

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = (url.scheme == "https")
      timeout_seconds = (service_check.timeout_ms / 1000.0)
      http.open_timeout = timeout_seconds
      http.read_timeout = timeout_seconds

      request_class = case request_method
      when "POST"
        Net::HTTP::Post
      else
        Net::HTTP::Get
      end

      request = request_class.new(url)
      merged_headers.each do |header, value|
        request[header] = value
      end

      if request_method == "POST" && config["body"].present?
        request.body = config["body"].to_s
      end

      http.request(request)
    end

    def merged_headers
      headers = config["headers"] || {}
      headers = headers.deep_stringify_keys

      auth = config["auth"] || {}
      case auth["type"]
      when "bearer"
        headers["Authorization"] = "Bearer #{auth['token']}" if auth["token"].present?
      when "basic"
        if auth["username"].present? && auth["password"].present?
          token = Base64.strict_encode64("#{auth['username']}:#{auth['password']}")
          headers["Authorization"] = "Basic #{token}"
        end
      end

      headers
    end

    def evaluate_response(response, duration_ms)
      expected_statuses = Array(config.fetch("expected_status", 200)).map(&:to_i)
      failure_reasons = []

      failure_reasons << "unexpected_status" unless expected_statuses.include?(response.code.to_i)

      body_text = response.body.to_s
      if config["body_contains"].present? && !body_text.include?(config["body_contains"].to_s)
        failure_reasons << "body_contains_mismatch"
      end

      if config["body_regex"].present?
        regex = Regexp.new(config["body_regex"].to_s)
        failure_reasons << "body_regex_mismatch" unless regex.match?(body_text)
      end

      json_path_result = nil
      if config["json_path"].present?
        json_obj = JSON.parse(body_text)
        json_path_values = JsonPath.new(config["json_path"].to_s).on(json_obj)
        json_path_result = json_path_values.first

        if config["json_expected"].present? && json_path_result.to_s != config["json_expected"].to_s
          failure_reasons << "json_path_mismatch"
        end
      end

      latency_breached = service_check.max_latency_ms.present? && duration_ms > service_check.max_latency_ms
      status = if failure_reasons.any?
        "down"
      elsif latency_breached
        "degraded"
      else
        "up"
      end

      build_result(
        status: status,
        duration_ms: duration_ms,
        http_status_code: response.code.to_i,
        body_excerpt: body_text.first(MAX_BODY_EXCERPT),
        json_path_result: json_path_result&.to_s,
        latency_breached: latency_breached,
        metadata: {
          url: config["url"],
          method: config.fetch("method", "GET").upcase,
          failure_reasons: failure_reasons
        }
      )
    rescue JSON::ParserError
      build_result(
        status: "down",
        duration_ms: duration_ms,
        http_status_code: response.code.to_i,
        body_excerpt: response.body.to_s.first(MAX_BODY_EXCERPT),
        error_class: "JSON::ParserError",
        error_message: "Response body is not valid JSON for json_path validation",
        metadata: { reason: "invalid_json" }
      )
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def elapsed_ms_since(started)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    end
  end
end
