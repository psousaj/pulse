module Monitoring
  class MonitorCheckExecutionService
    def initialize(monitor:, scheduled_at: nil)
      @monitor = monitor
      @scheduled_at = scheduled_at
    end

    def call
      strategy = Monitoring::Strategies::Registry.fetch(monitor.strategy)
      payload = strategy.call(monitor)
      event = persist_event(payload)
      ProcessHealthEventJob.perform_later(event.id)
      event
    ensure
      monitor.schedule_next_run!(from: Time.current)
      monitor.release_lease!
    end

    private

    attr_reader :monitor, :scheduled_at

    def persist_event(payload)
      checked_at = payload[:checked_at] || Time.current

      monitor.health_events.create!(
        account: monitor.account,
        service: monitor.service,
        monitor_source_binding: nil,
        source: "internal",
        status: payload.fetch(:status),
        authoritative: monitor.authoritative_without_binding?(source: "internal"),
        latency_ms: payload[:latency_ms],
        ttfb_ms: payload[:ttfb_ms],
        tls_ms: payload[:tls_ms],
        dns_ms: payload[:dns_ms],
        error_message: payload[:error_message],
        metadata_json: (payload[:metadata_json] || {}).merge(scheduled_at: parsed_scheduled_at),
        checked_at: checked_at
      )
    end

    def parsed_scheduled_at
      return if scheduled_at.blank?

      Time.iso8601(scheduled_at)
    rescue ArgumentError
      nil
    end
  end
end
