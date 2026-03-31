class DashboardController < ApplicationController
  before_action :require_login

  def index
    @total_services = Service.count
    @operational_services = Service.where(current_status: "operational").count
    @degraded_services = Service.where(current_status: "degraded").count
    @down_services = Service.where(current_status: "down").count
    @recent_incidents = Incident.order(opened_at: :desc).limit(10)
  end
end
