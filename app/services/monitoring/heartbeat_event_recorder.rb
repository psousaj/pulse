module Monitoring
  class HeartbeatEventRecorder
    def self.emit_up!(heartbeat_token, checked_at: Time.current)
      emit!(heartbeat_token, status: "up", checked_at: checked_at)
    end

    def self.emit_down!(heartbeat_token, checked_at: Time.current)
      emit!(heartbeat_token, status: "down", checked_at: checked_at, error_message: "heartbeat_missed")
    end

    def self.emit!(heartbeat_token, status:, checked_at:, error_message: nil)
      monitor = heartbeat_token.monitor
      return if monitor.blank?

      binding = MonitorSourceBinding.find_by(token_digest: heartbeat_token.token_digest)
      event = monitor.health_events.create!(
        account: heartbeat_token.account,
        service: monitor.service || heartbeat_token.service,
        monitor_source_binding: binding,
        source: "heartbeat",
        status: status,
        authoritative: binding.present? ? binding.primary? : monitor.authoritative_without_binding?(source: "heartbeat"),
        error_message: error_message,
        metadata_json: { heartbeat_token_id: heartbeat_token.id },
        checked_at: checked_at
      )

      ProcessHealthEventJob.perform_later(event.id)
      event
    end
  end
end
