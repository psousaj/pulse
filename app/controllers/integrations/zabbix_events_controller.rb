module Integrations
  class ZabbixEventsController < ActionController::API
    def create
      endpoint = authenticate_endpoint
      return render json: { error: "unauthorized" }, status: :unauthorized if endpoint.blank?

      result = IntegrationAdapters::ZabbixAdapter.new(endpoint: endpoint, payload: request_payload).receive_event
      if result.ok?
        render json: { status: "accepted", duplicate: result.duplicate?, ingress_id: result.ingress&.id }, status: :accepted
      else
        render json: { error: result.error_code }, status: :unprocessable_entity
      end
    end

    private

    def authenticate_endpoint
      secret = bearer_token
      return if secret.blank?

      digest = IntegrationEndpoint.digest(secret)
      IntegrationEndpoint.enabled.find_by(provider: "zabbix", secret_digest: digest)
    end

    def bearer_token
      auth = request.headers["Authorization"].to_s
      match = auth.match(/^Bearer\s+(.+)$/)
      match && match[1]
    end

    def request_payload
      params.to_unsafe_h.except("controller", "action")
    end
  end
end
