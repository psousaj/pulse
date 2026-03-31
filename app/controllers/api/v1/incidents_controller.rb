module Api
  module V1
    class IncidentsController < Api::ApplicationController
      def index
        incidents = current_account.incidents.order(opened_at: :desc).limit(100)

        render json: {
          incidents: incidents.map { |incident| incident_payload(incident) }
        }
      end

      def show
        incident = current_account.incidents.find(params[:id])
        render json: { incident: incident_payload(incident) }
      end

      private

      def incident_payload(incident)
        {
          id: incident.id,
          service_id: incident.service_id,
          service_check_id: incident.service_check_id,
          state: incident.state,
          severity: incident.severity,
          title: incident.title,
          trigger_kind: incident.trigger_kind,
          opened_at: incident.opened_at,
          acknowledged_at: incident.acknowledged_at,
          resolved_at: incident.resolved_at
        }
      end
    end
  end
end
