module Monitoring
  class IncidentDetectionEngine
    Result = Struct.new(:action, :next_status, :severity, :incident, keyword_init: true)

    def initialize(health_event:)
      @health_event = health_event
      @monitor = health_event.monitor
      @active_incident = monitor.incidents.active.order(created_at: :desc).first
    end

    def call
      return Result.new(action: :ignore, next_status: monitor.current_status) unless health_event.authoritative?

      if health_event.up?
        resolve_or_stabilize
      else
        open_refresh_or_escalate
      end
    end

    private

    attr_reader :health_event, :monitor, :active_incident

    def resolve_or_stabilize
      return Result.new(action: :noop, next_status: "up") if active_incident.blank?
      return Result.new(action: :resolve, next_status: "up", incident: active_incident) if resolve_threshold_met?

      Result.new(action: :noop, next_status: active_incident.severity, incident: active_incident)
    end

    def open_refresh_or_escalate
      return immediate_integration_result if immediate_source?
      return Result.new(action: :noop, next_status: monitor.current_status) unless open_threshold_met?

      stateful_non_up_result
    end

    def immediate_integration_result
      if active_incident.blank?
        Result.new(action: :open, next_status: health_event.status, severity: health_event.status)
      elsif active_incident.severity != health_event.status
        Result.new(action: :change_severity, next_status: health_event.status, severity: health_event.status, incident: active_incident)
      else
        Result.new(action: :refresh, next_status: active_incident.severity, severity: active_incident.severity, incident: active_incident)
      end
    end

    def stateful_non_up_result
      if active_incident.blank?
        Result.new(action: :open, next_status: health_event.status, severity: health_event.status)
      elsif active_incident.severity != health_event.status
        Result.new(action: :change_severity, next_status: health_event.status, severity: health_event.status, incident: active_incident)
      else
        Result.new(action: :refresh, next_status: active_incident.severity, severity: active_incident.severity, incident: active_incident)
      end
    end

    def immediate_source?
      health_event.integration? || health_event.heartbeat?
    end

    def open_threshold_met?
      recent = authoritative_events(limit: monitor.failure_threshold)
      return false if recent.size < monitor.failure_threshold

      recent.all?(&:failure?)
    end

    def resolve_threshold_met?
      return true if immediate_source?

      recent = authoritative_events(limit: monitor.success_threshold)
      return false if recent.size < monitor.success_threshold

      recent.all?(&:up?)
    end

    def authoritative_events(limit:)
      monitor.health_events.authoritative.recent.limit(limit)
    end
  end
end
