class DashboardController < ApplicationController
  before_action :require_login
  before_action -> { require_permissions!("monitor.read", "incident.read", "admin") }

  def index
    account = current_account
    @dashboard_generated_at = Time.current
    @services = account.services.includes(:monitors).order(:name).load
    @monitors = account.monitors.includes(:service, :monitor_source_bindings).order(:name).load
    @integration_endpoints = account.integration_endpoints.includes(:monitor_source_bindings).order(:provider, :name).load
    @recent_incidents = account.incidents.includes(:service, :monitor).order(opened_at: :desc).limit(10).load
    @rollups_24h = MonitorSlaRollup.where(account: account, monitor_id: @monitors.map(&:id), window_key: "24h").index_by(&:monitor_id)

    @total_services = @services.count
    @total_monitors = @monitors.count
    @up_monitors = @monitors.count(&:up?)
    @degraded_monitors = @monitors.count(&:degraded?)
    @down_monitors = @monitors.count(&:down?)
    @active_incidents = account.incidents.active.includes(:service, :monitor).order(opened_at: :desc).limit(6).load
    @active_incidents_count = account.incidents.active.count
    @resolved_incidents_today = account.incidents.where(state: "resolved", resolved_at: Time.current.beginning_of_day..Time.current).count
    @integration_ingresses_24h = account.integration_event_ingresses.where(received_at: 24.hours.ago..Time.current).count
    @health_events_last_hour = account.health_events.where(checked_at: 1.hour.ago..Time.current).count
    @strategy_mix = @monitors.group_by(&:strategy).transform_values(&:count).sort_by { |strategy, count| [ -count, strategy ] }

    monitors_by_service = @monitors.group_by(&:service_id)
    @service_rows = @services.map do |service|
      service_monitors = monitors_by_service.fetch(service.id, [])
      rollups = service_monitors.filter_map { |monitor| @rollups_24h[monitor.id] }
      uptime_pct = if rollups.any?
        rollups.sum { |rollup| rollup.uptime_pct.to_f } / rollups.size
      end

      {
        service: service,
        monitors: service_monitors,
        up_count: service_monitors.count(&:up?),
        degraded_count: service_monitors.count(&:degraded?),
        down_count: service_monitors.count(&:down?),
        uptime_pct: uptime_pct
      }
    end.sort_by { |row| [ status_rank(row[:service].current_status), row[:service].name ] }

    @uptime_series = @service_rows.filter_map { |row| row[:uptime_pct] }
  end

  private

  def status_rank(status)
    case status.to_s
    when "down"
      0
    when "degraded"
      1
    else
      2
    end
  end
end
