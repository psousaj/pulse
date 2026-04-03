module Public
  class StatusPagesController < ApplicationController
    def index
      @services = Service.publicly_visible.includes(:monitors).order(:name)
      monitor_ids = @services.flat_map(&:monitor_ids)
      @rollups_24h = MonitorSlaRollup.where(monitor_id: monitor_ids, window_key: "24h").index_by(&:monitor_id)
      @recent_incidents = Incident
        .includes(:service, :monitor)
        .where(service_id: @services.select(:id))
        .order(opened_at: :desc)
        .limit(20)
    end
  end
end
