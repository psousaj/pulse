module Api
  class HeartbeatsController < ActionController::API
    DEFAULT_LIMIT_PER_MINUTE = 20

    def create
      token = params[:token].to_s
      digest = HeartbeatToken.digest(token)
      heartbeat_token = HeartbeatToken.includes(:service, :account).find_by(token_digest: digest, enabled: true)

      return render json: { error: "heartbeat_not_found" }, status: :not_found if heartbeat_token.blank?
      return render json: { error: "rate_limited" }, status: :too_many_requests if rate_limited?(heartbeat_token)

      heartbeat_token.mark_seen!
      if heartbeat_token.monitor.present?
        Monitoring::HeartbeatEventRecorder.emit_up!(heartbeat_token)
      else
        Monitoring::IncidentEngine.resolve_heartbeat_incidents!(heartbeat_token)
      end

      render json: { status: "accepted", service: heartbeat_token.service.slug }, status: :accepted
    end

    private

    def rate_limited?(heartbeat_token)
      minute_bucket = Time.current.utc.strftime("%Y%m%d%H%M")
      key = "heartbeat-rate:#{heartbeat_token.id}:#{minute_bucket}"
      current = Rails.cache.read(key).to_i
      limit = heartbeat_rate_limit_for(heartbeat_token)
      return true if current >= limit

      Rails.cache.write(key, current + 1, expires_in: 2.minutes)
      false
    end

    def heartbeat_rate_limit_for(heartbeat_token)
      service_override = Setting.find_by(
        account_id: heartbeat_token.account_id,
        namespace: "heartbeat",
        key: "rate_limit_per_minute_service_#{heartbeat_token.service_id}"
      )
      return service_override.value_json["value"].to_i if service_override&.value_json&.is_a?(Hash) && service_override.value_json["value"].present?

      global = Setting.find_by(account_id: heartbeat_token.account_id, namespace: "heartbeat", key: "rate_limit_per_minute")
      return global.value_json["value"].to_i if global&.value_json&.is_a?(Hash) && global.value_json["value"].present?

      DEFAULT_LIMIT_PER_MINUTE
    end
  end
end
