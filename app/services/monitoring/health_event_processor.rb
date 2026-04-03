module Monitoring
  class HealthEventProcessor
    def initialize(health_event:)
      @health_event = health_event
      @monitor = health_event.monitor
    end

    def call
      decision = Monitoring::IncidentDetectionEngine.new(health_event: health_event).call

      case decision.action
      when :ignore, :noop
        project_status!(decision.next_status)
      when :open
        open_incident!(decision)
      when :change_severity
        change_severity!(decision)
      when :refresh
        refresh_incident!(decision)
      when :resolve
        resolve_incident!(decision)
      end
    end

    private

    attr_reader :health_event, :monitor

    def open_incident!(decision)
      incident = Incident.create!(
        account: monitor.account,
        service: monitor.service,
        monitor: monitor,
        service_check: nil,
        state: "open",
        severity: decision.severity,
        title: incident_title(decision.severity),
        trigger_kind: trigger_kind,
        opened_at: health_event.checked_at,
        root_cause: root_cause,
        first_health_event: health_event,
        last_health_event: health_event
      )

      capture_evidence_for!(health_event)
      IncidentEvent.create!(
        account: monitor.account,
        incident: incident,
        event_type: "opened",
        actor_type: "system",
        actor_ref: actor_ref,
        from_state: nil,
        to_state: "open",
        payload_json: {
          health_event_id: health_event.id,
          source: health_event.source,
          severity: decision.severity,
          checked_at: health_event.checked_at
        }
      )

      NotificationDispatchJob.perform_later(incident.id, "incident_opened")
      project_status!(decision.next_status)
    end

    def change_severity!(decision)
      incident = decision.incident
      previous = incident.severity
      incident.update!(severity: decision.severity, last_health_event: health_event, root_cause: incident.root_cause.presence || root_cause)

      IncidentEvent.create!(
        account: monitor.account,
        incident: incident,
        event_type: "severity_changed",
        actor_type: "system",
        actor_ref: actor_ref,
        from_state: previous,
        to_state: decision.severity,
        payload_json: {
          health_event_id: health_event.id,
          source: health_event.source,
          checked_at: health_event.checked_at
        }
      )

      project_status!(decision.next_status)
    end

    def refresh_incident!(decision)
      decision.incident.update!(last_health_event: health_event)
      project_status!(decision.next_status)
    end

    def resolve_incident!(decision)
      incident = decision.incident
      from_state = incident.state
      incident.update!(last_health_event: health_event)
      incident.resolve!

      IncidentEvent.create!(
        account: monitor.account,
        incident: incident,
        event_type: "resolved",
        actor_type: "system",
        actor_ref: actor_ref,
        from_state: from_state,
        to_state: "resolved",
        payload_json: {
          health_event_id: health_event.id,
          source: health_event.source,
          checked_at: health_event.checked_at
        }
      )

      NotificationDispatchJob.perform_later(incident.id, "incident_resolved")
      project_status!(decision.next_status)
    end

    def capture_evidence_for!(event)
      path = Monitoring::IncidentEvidenceCapturer.call(monitor: monitor, health_event: event)
      event.update_column(:screenshot_path, path) if path.present?
    end

    def project_status!(next_status)
      monitor.update!(current_status: normalize_monitor_status(next_status))
      Monitoring::StatusProjector.refresh_service!(monitor.service) if monitor.service.present?
    end

    def normalize_monitor_status(status)
      value = status.to_s
      return value if %w[up degraded down].include?(value)

      "up"
    end

    def incident_title(severity)
      "#{monitor.name} #{severity}"
    end

    def trigger_kind
      case health_event.source
      when "heartbeat"
        "heartbeat_missed"
      when "integration"
        "integration_event"
      else
        health_event.degraded? ? "check_degraded" : "check_failure"
      end
    end

    def root_cause
      metadata = health_event.metadata_json.is_a?(Hash) ? health_event.metadata_json : {}
      Array(metadata["failure_reasons"]).join(", ").presence ||
        metadata["trigger"].to_s.presence ||
        health_event.error_message.presence ||
        "#{health_event.source} reported #{health_event.status}"
    end

    def actor_ref
      if health_event.monitor_source_binding.present?
        [ health_event.monitor_source_binding.provider, health_event.monitor_source_binding.external_ref ].compact.join(":")
      else
        "monitor:#{monitor.id}:#{health_event.source}"
      end
    end
  end
end
