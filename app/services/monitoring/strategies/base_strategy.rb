module Monitoring
  module Strategies
    class BaseStrategy
      def self.call(monitor)
        new(monitor).call
      end

      def self.capture_evidence(_monitor)
        nil
      end

      def initialize(monitor)
        @monitor = monitor
      end

      private

      attr_reader :monitor

      def config
        monitor.config
      end

      def build_event(status:, checked_at: Time.current, latency_ms: nil, ttfb_ms: nil, tls_ms: nil, dns_ms: nil, error_message: nil, metadata: {})
        {
          status: status,
          checked_at: checked_at,
          latency_ms: latency_ms,
          ttfb_ms: ttfb_ms,
          tls_ms: tls_ms,
          dns_ms: dns_ms,
          error_message: error_message,
          metadata_json: metadata
        }
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def elapsed_ms_since(started)
        ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      end

      def degraded_threshold_ms
        threshold = config["degraded_threshold_ms"].to_i
        threshold.positive? ? threshold : nil
      end
    end
  end
end
