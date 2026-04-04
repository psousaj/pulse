module Api
  module V1
    class MonitorSlaRollupsController < Api::ApplicationController
      before_action -> { require_permissions!("monitor.read", "admin") }

      def index
        rollups = current_account.monitor_sla_rollups.includes(:monitor).order(window_end: :desc, monitor_id: :asc)
        rollups = rollups.where(monitor_id: params[:monitor_id]) if params[:monitor_id].present?
        rollups = rollups.where(window_key: params[:window_key]) if params[:window_key].present?

        render json: {
          monitor_sla_rollups: rollups.map { |rollup| rollup_payload(rollup) }
        }
      end

      private

      def rollup_payload(rollup)
        {
          id: rollup.id,
          monitor_id: rollup.monitor_id,
          monitor_name: rollup.monitor.name,
          monitor_slug: rollup.monitor.slug,
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
