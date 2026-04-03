module Api
  module V1
    class MonitorsController < Api::ApplicationController
      def index
        monitors = current_account.monitors.includes(:service, :monitor_source_bindings, :monitor_sla_rollups).order(:name)

        render json: {
          monitors: monitors.map { |monitor| monitor_payload(monitor) }
        }
      end

      def show
        monitor = current_account.monitors.includes(:service, :monitor_source_bindings, :monitor_sla_rollups).find(params[:id])

        render json: {
          monitor: monitor_payload(monitor).merge(
            config: monitor.config,
            bindings: monitor.monitor_source_bindings.order(:role, :kind).map { |binding| binding_payload(binding) },
            sla_rollups: monitor.monitor_sla_rollups.order(:window_key).map { |rollup| rollup_payload(rollup) },
            recent_health_events: monitor.health_events.recent.limit(20).map { |event| event_payload(event) },
            recent_incidents: monitor.incidents.order(opened_at: :desc).limit(10).map { |incident| incident_payload(incident) }
          )
        }
      end

      private

      def monitor_payload(monitor)
        {
          id: monitor.id,
          service_id: monitor.service_id,
          service_name: monitor.service&.name,
          name: monitor.name,
          slug: monitor.slug,
          strategy: monitor.strategy,
          status: monitor.current_status,
          enabled: monitor.enabled,
          interval_seconds: monitor.interval_seconds,
          next_run_at: monitor.next_run_at,
          last_run_at: monitor.last_run_at,
          failure_threshold: monitor.failure_threshold,
          success_threshold: monitor.success_threshold,
          primary_binding: binding_payload(monitor.primary_binding)
        }
      end

      def binding_payload(binding)
        return nil if binding.blank?

        {
          id: binding.id,
          kind: binding.kind,
          role: binding.role,
          provider: binding.provider,
          external_ref: binding.external_ref,
          integration_endpoint_id: binding.integration_endpoint_id,
          enabled: binding.enabled,
          config: binding.config
        }
      end

      def rollup_payload(rollup)
        {
          id: rollup.id,
          window_key: rollup.window_key,
          uptime_pct: rollup.uptime_pct.to_f,
          degraded_pct: rollup.degraded_pct.to_f,
          down_pct: rollup.down_pct.to_f,
          down_seconds: rollup.down_seconds,
          degraded_seconds: rollup.degraded_seconds,
          window_start: rollup.window_start,
          window_end: rollup.window_end
        }
      end

      def event_payload(event)
        {
          id: event.id,
          source: event.source,
          status: event.status,
          authoritative: event.authoritative,
          latency_ms: event.latency_ms,
          error_message: event.error_message,
          screenshot_path: event.screenshot_path,
          checked_at: event.checked_at,
          metadata: event.metadata_json
        }
      end

      def incident_payload(incident)
        {
          id: incident.id,
          state: incident.state,
          severity: incident.severity,
          title: incident.title,
          trigger_kind: incident.trigger_kind,
          root_cause: incident.root_cause,
          duration_seconds: incident.duration_seconds,
          opened_at: incident.opened_at,
          resolved_at: incident.resolved_at
        }
      end
    end
  end
end
