module CheckRunners
  class BaseRunner
    def self.call(service_check)
      new(service_check).call
    end

    def initialize(service_check)
      @service_check = service_check
    end

    private

    attr_reader :service_check

    def config
      service_check.config
    end

    def build_result(status:, duration_ms:, http_status_code: nil, body_excerpt: nil, json_path_result: nil, latency_breached: false, timed_out: false, error_class: nil, error_message: nil, metadata: {})
      {
        status: status,
        duration_ms: duration_ms,
        http_status_code: http_status_code,
        body_excerpt: body_excerpt,
        json_path_result: json_path_result,
        latency_breached: latency_breached,
        timed_out: timed_out,
        error_class: error_class,
        error_message: error_message,
        metadata_json: metadata
      }
    end
  end
end
