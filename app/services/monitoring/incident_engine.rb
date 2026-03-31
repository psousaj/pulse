module Monitoring
  class IncidentEngine
    FAILURE_THRESHOLD = 2
    SUCCESS_THRESHOLD = 2
    LATENCY_THRESHOLD = 3

    def initialize(service_check:, check_result:)
      @service_check = service_check
      @check_result = check_result
      @service = service_check.service
      @account = service_check.account
    end

    def call
      if check_result.failure? && service_check.consecutive_failures >= FAILURE_THRESHOLD
        open_or_refresh_incident!(severity: "down", trigger_kind: "check_failure")
      elsif degraded_streak?
        open_or_refresh_incident!(severity: "degraded", trigger_kind: "check_latency")
      elsif service_check.consecutive_successes >= SUCCESS_THRESHOLD
        resolve_check_incidents!
      end

      refresh_service_status!
    end

    def self.open_heartbeat_incident!(heartbeat_token)
      incident = Incident.active.find_or_initialize_by(
        account: heartbeat_token.account,
        service: heartbeat_token.service,
        service_check: nil,
        trigger_kind: "heartbeat_missed",
        severity: "down"
      )

      created = incident.new_record?
      if created
        incident.state = "open"
        incident.title = "Heartbeat missed"
        incident.opened_at = Time.current
      end

      incident.save!
      heartbeat_token.service.update!(current_status: "down")

      if created
        IncidentEvent.create!(
          account: heartbeat_token.account,
          incident: incident,
          event_type: "opened",
          actor_type: "system",
          from_state: nil,
          to_state: "open"
        )
        NotificationDispatchJob.perform_later(incident.id, "incident_opened") unless heartbeat_token.service.in_maintenance_window?
      end
    end

    def self.resolve_heartbeat_incidents!(heartbeat_token)
      Incident.active
        .where(
          account: heartbeat_token.account,
          service: heartbeat_token.service,
          trigger_kind: "heartbeat_missed"
        )
        .find_each do |incident|
          from_state = incident.state
          incident.resolve!
          IncidentEvent.create!(
            account: heartbeat_token.account,
            incident: incident,
            event_type: "resolved",
            actor_type: "system",
            from_state: from_state,
            to_state: "resolved"
          )
          NotificationDispatchJob.perform_later(incident.id, "incident_resolved") unless heartbeat_token.service.in_maintenance_window?
        end
    end

    private

    attr_reader :service_check, :check_result, :service, :account

    def degraded_streak?
      return false unless check_result.latency_breached?

      recent = service_check.check_results.recent.limit(LATENCY_THRESHOLD)
      return false if recent.size < LATENCY_THRESHOLD

      recent.all? { |result| result.latency_breached? && !result.failure? }
    end

    def open_or_refresh_incident!(severity:, trigger_kind:)
      incident = Incident.active
        .where(account:, service:, service_check:, severity:, trigger_kind:)
        .order(created_at: :desc)
        .first

      if incident
        incident.update!(last_check_result: check_result)
        return incident
      end

      incident = Incident.create!(
        account:,
        service:,
        service_check:,
        state: "open",
        severity:,
        title: "#{service.name} #{severity}",
        trigger_kind:,
        opened_at: Time.current,
        first_check_result: check_result,
        last_check_result: check_result
      )

      IncidentEvent.create!(
        account:,
        incident: incident,
        event_type: "opened",
        actor_type: "system",
        from_state: nil,
        to_state: "open"
      )
      NotificationDispatchJob.perform_later(incident.id, "incident_opened") unless service.in_maintenance_window?
      incident
    end

    def resolve_check_incidents!
      Incident.active.where(account:, service:, service_check:).find_each do |incident|
        from_state = incident.state
        incident.resolve!
        IncidentEvent.create!(
          account:,
          incident: incident,
          event_type: "resolved",
          actor_type: "system",
          from_state: from_state,
          to_state: "resolved"
        )
        NotificationDispatchJob.perform_later(incident.id, "incident_resolved") unless service.in_maintenance_window?
      end
    end

    def refresh_service_status!
      active_incidents = Incident.active.where(service: service)

      next_status = if active_incidents.exists?(severity: "down")
        "down"
      elsif active_incidents.exists?(severity: "degraded")
        "degraded"
      elsif check_result.degraded?
        "degraded"
      else
        "operational"
      end

      service.update!(current_status: next_status)
    end
  end
end
