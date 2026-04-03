class DashboardController < ApplicationController
  before_action :require_login

  def index
    account = current_account
    @services = account.services.order(:name)
    @monitors = account.monitors.includes(:service, :monitor_source_bindings).order(:name)
    @integration_endpoints = account.integration_endpoints.includes(:monitor_source_bindings).order(:provider, :name)
    @recent_incidents = account.incidents.includes(:service, :monitor).order(opened_at: :desc).limit(10)
    @rollups_24h = MonitorSlaRollup.where(account: account, monitor_id: @monitors.select(:id), window_key: "24h").index_by(&:monitor_id)

    @total_services = @services.count
    @total_monitors = @monitors.count
    @up_monitors = @monitors.count(&:up?)
    @degraded_monitors = @monitors.count(&:degraded?)
    @down_monitors = @monitors.count(&:down?)
  end
end
