module Public
  class StatusPagesController < ApplicationController
    def index
      @services = Service.publicly_visible.order(:name)
      @recent_incidents = Incident
        .where(service_id: @services.select(:id))
        .order(opened_at: :desc)
        .limit(20)
    end
  end
end
