module Monitoring
  class CheckExecutionService
    def initialize(service_check:, scheduled_at: nil)
      @service_check = service_check
      @scheduled_at = scheduled_at
    end

    def call
      started_at = Time.current
      runner = CheckRunners::Registry.fetch(service_check.health_check_type.key)
      payload = runner.call(service_check)
      finished_at = Time.current

      result = persist_result(payload, started_at:, finished_at:)
      update_counters!(result)
      Monitoring::IncidentEngine.new(service_check:, check_result: result).call
      result
    rescue StandardError => e
      finished_at = Time.current
      result = persist_result(error_payload(e), started_at:, finished_at:)
      update_counters!(result)
      Monitoring::IncidentEngine.new(service_check:, check_result: result).call
      result
    ensure
      service_check.schedule_next_run!(from: Time.current)
      service_check.release_lease!
    end

    private

    attr_reader :service_check, :scheduled_at

    def persist_result(payload, started_at:, finished_at:)
      service_check.check_results.create!(
        account: service_check.account,
        service: service_check.service,
        scheduled_at: parsed_scheduled_at,
        started_at:,
        finished_at:,
        duration_ms: payload[:duration_ms],
        status: payload[:status],
        http_status_code: payload[:http_status_code],
        body_excerpt: payload[:body_excerpt],
        json_path_result: payload[:json_path_result],
        latency_breached: payload.fetch(:latency_breached, false),
        timed_out: payload.fetch(:timed_out, false),
        error_class: payload[:error_class],
        error_message: payload[:error_message],
        metadata_json: payload[:metadata_json]
      )
    end

    def update_counters!(result)
      if result.failure?
        service_check.update!(
          consecutive_failures: service_check.consecutive_failures + 1,
          consecutive_successes: 0
        )
      else
        service_check.update!(
          consecutive_failures: 0,
          consecutive_successes: service_check.consecutive_successes + 1
        )
      end
    end

    def parsed_scheduled_at
      return if scheduled_at.blank?

      Time.iso8601(scheduled_at)
    rescue ArgumentError
      nil
    end

    def error_payload(error)
      {
        status: "error",
        duration_ms: nil,
        error_class: error.class.name,
        error_message: error.message,
        metadata_json: { reason: "execution_exception" }
      }
    end
  end
end
