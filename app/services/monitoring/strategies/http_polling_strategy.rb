require "base64"
require "json"
require "jsonpath"
require "net/http"
require "uri"

module Monitoring
  module Strategies
    class HttpPollingStrategy < BaseStrategy
      MAX_BODY_EXCERPT = 500

      def call
        started = monotonic_now
        response = perform_request
        latency_ms = elapsed_ms_since(started)
        checked_at = Time.current

        evaluate_response(response, latency_ms:, checked_at:)
      rescue Net::OpenTimeout, Net::ReadTimeout => error
        build_event(
          status: "down",
          checked_at: Time.current,
          error_message: error.message,
          metadata: { reason: "timeout", error_class: error.class.name }
        )
      rescue StandardError => error
        build_event(
          status: "down",
          checked_at: Time.current,
          error_message: error.message,
          metadata: { reason: "exception", error_class: error.class.name }
        )
      end

      private

      def perform_request
        url = URI.parse(config.fetch("url"))
        request_method = config.fetch("method", "GET").upcase

        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = (url.scheme == "https")
        timeout_seconds = (config.fetch("timeout_ms", 5000).to_i / 1000.0)
        http.open_timeout = timeout_seconds
        http.read_timeout = timeout_seconds

        request_class = request_method == "POST" ? Net::HTTP::Post : Net::HTTP::Get
        request = request_class.new(url)
        merged_headers.each do |header, value|
          request[header] = value
        end
        request.body = config["body"].to_s if request_method == "POST" && config["body"].present?

        http.request(request)
      end

      def merged_headers
        headers = (config["headers"] || {}).deep_stringify_keys
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

      def evaluate_response(response, latency_ms:, checked_at:)
        expected_statuses = Array(config.fetch("expected_status", 200)).map(&:to_i)
        body_text = response.body.to_s
        failure_reasons = []

        failure_reasons << "unexpected_status" unless expected_statuses.include?(response.code.to_i)

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
          values = JsonPath.new(config["json_path"].to_s).on(json_obj)
          json_path_result = values.first

          if config["json_expected"].present? && json_path_result.to_s != config["json_expected"].to_s
            failure_reasons << "json_path_mismatch"
          end
        end

        degraded = degraded_threshold_ms.present? && latency_ms > degraded_threshold_ms
        status = if failure_reasons.any?
          "down"
        elsif degraded
          "degraded"
        else
          "up"
        end

        build_event(
          status: status,
          checked_at: checked_at,
          latency_ms: latency_ms,
          ttfb_ms: latency_ms,
          error_message: failure_reasons.any? ? failure_reasons.join(", ") : nil,
          metadata: {
            url: config["url"],
            method: config.fetch("method", "GET").upcase,
            http_status_code: response.code.to_i,
            body_excerpt: body_text.first(MAX_BODY_EXCERPT),
            json_path_result: json_path_result,
            failure_reasons: failure_reasons
          }
        )
      rescue JSON::ParserError => error
        build_event(
          status: "down",
          checked_at: checked_at,
          latency_ms: latency_ms,
          ttfb_ms: latency_ms,
          error_message: error.message,
          metadata: {
            reason: "invalid_json",
            http_status_code: response.code.to_i,
            body_excerpt: body_text.first(MAX_BODY_EXCERPT)
          }
        )
      end
    end
  end
end
