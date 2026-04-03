require "digest"

module IntegrationAdapters
  class ZabbixAdapter < BaseAdapter
    def receive_event
      existing = endpoint.integration_event_ingresses.find_by(idempotency_key: idempotency_key)
      return Result.new(ok?: true, duplicate?: true, ingress: existing, health_event: existing&.health_event) if existing.present?

      binding = find_binding
      return reject_without_binding unless binding.present?

      ingress = nil
      health_event = nil

      ActiveRecord::Base.transaction do
        ingress = endpoint.integration_event_ingresses.create!(
          account: endpoint.account,
          provider: endpoint.provider,
          idempotency_key: idempotency_key,
          status: "received",
          external_ref: external_ref,
          payload_json: payload,
          received_at: Time.current,
          monitor_source_binding: binding
        )

        health_event = emit_health_event(binding)
        ingress.update!(health_event: health_event, status: "accepted", processed_at: Time.current)
      end

      Result.new(ok?: true, duplicate?: false, ingress: ingress, health_event: health_event)
    rescue ActiveRecord::RecordNotUnique
      existing = endpoint.integration_event_ingresses.find_by(idempotency_key: idempotency_key)
      Result.new(ok?: true, duplicate?: true, ingress: existing, health_event: existing&.health_event)
    end

    private

    def emit_health_event(binding)
      status = binding.external_status_map(payload["status"])
      health_event = binding.monitor.health_events.create!(
        account: endpoint.account,
        service: binding.monitor.service,
        monitor_source_binding: binding,
        source: binding.heartbeat? ? "heartbeat" : "integration",
        status: status,
        authoritative: binding.primary?,
        error_message: payload["trigger"].to_s.presence,
        metadata_json: normalize_payload,
        checked_at: event_time_for(payload["timestamp"])
      )

      ProcessHealthEventJob.perform_later(health_event.id)
      health_event
    end

    def find_binding
      endpoint.monitor_source_bindings.enabled.integration.find_by(external_ref: external_ref)
    end

    def reject_without_binding
      ingress = endpoint.integration_event_ingresses.create!(
        account: endpoint.account,
        provider: endpoint.provider,
        idempotency_key: idempotency_key,
        status: "rejected",
        external_ref: external_ref,
        error_code: "monitor_binding_not_found",
        payload_json: payload,
        received_at: Time.current
      )

      Result.new(ok?: false, duplicate?: false, ingress: ingress, error_code: "monitor_binding_not_found")
    end

    def normalize_payload
      {
        "host" => payload["host"],
        "status" => payload["status"],
        "trigger" => payload["trigger"],
        "timestamp" => payload["timestamp"]
      }
    end

    def external_ref
      payload["host"].to_s
    end

    def idempotency_key
      payload["event_id"].to_s.presence || Digest::SHA256.hexdigest(payload.to_json)
    end
  end
end
