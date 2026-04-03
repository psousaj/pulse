module Monitoring
  class StatusProjector
    def self.refresh_service!(service)
      monitors = service.monitors.enabled
      next_status = if monitors.where(current_status: "down").exists?
        "down"
      elsif monitors.where(current_status: "degraded").exists?
        "degraded"
      else
        "operational"
      end

      service.update!(current_status: next_status)
    end
  end
end
