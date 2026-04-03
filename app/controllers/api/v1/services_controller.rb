module Api
  module V1
    class ServicesController < Api::ApplicationController
      def index
        services = current_account.services.includes(:monitors).order(:name)
        render json: {
          services: services.map { |service| service_payload(service) }
        }
      end

      def show
        service = current_account.services.includes(monitors: [ :monitor_source_bindings, :monitor_sla_rollups ]).find(params[:id])
        render json: {
          service: service_payload(service).merge(
            monitors: service.monitors.order(:name).map { |monitor| monitor_payload(monitor) }
          )
        }
      end

      private

      def service_payload(service)
        {
          id: service.id,
          name: service.name,
          slug: service.slug,
          status: service.current_status,
          paused: service.paused,
          visibility: service.visibility,
          monitor_count: service.monitors.size,
          down_monitors: service.monitors.count(&:down?),
          degraded_monitors: service.monitors.count(&:degraded?)
        }
      end

      def monitor_payload(monitor)
        {
          id: monitor.id,
          name: monitor.name,
          slug: monitor.slug,
          strategy: monitor.strategy,
          status: monitor.current_status,
          enabled: monitor.enabled,
          interval_seconds: monitor.interval_seconds,
          next_run_at: monitor.next_run_at,
          last_run_at: monitor.last_run_at,
          primary_binding: binding_payload(monitor.primary_binding),
          sla_rollups: monitor.monitor_sla_rollups.order(:window_key).map { |rollup| rollup_payload(rollup) }
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
          integration_endpoint_id: binding.integration_endpoint_id
        }
      end

      def rollup_payload(rollup)
        {
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
    end
  end
end
