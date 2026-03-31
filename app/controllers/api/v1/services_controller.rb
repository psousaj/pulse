module Api
  module V1
    class ServicesController < Api::ApplicationController
      def index
        services = current_account.services.order(:name)
        render json: {
          services: services.map { |service| service_payload(service) }
        }
      end

      def show
        service = current_account.services.find(params[:id])
        render json: {
          service: service_payload(service).merge(
            checks: service.service_checks.order(:name).map do |check|
              {
                id: check.id,
                name: check.name,
                enabled: check.enabled,
                critical: check.critical,
                interval_seconds: check.interval_seconds,
                next_run_at: check.next_run_at,
                last_run_at: check.last_run_at
              }
            end
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
          visibility: service.visibility
        }
      end
    end
  end
end
