require "digest"

module Api
  class ApplicationController < ActionController::API
    before_action :authenticate_api_request!

    private

    attr_reader :current_account, :current_user

    def authenticate_api_request!
      token = bearer_token
      return render_unauthorized("missing_bearer_token") if token.blank?

      payload = decode_jwt(token)
      return render_unauthorized("invalid_token") if payload.blank?

      access_token = ApiAccessToken.active.includes(:user, :account).find_by(jti: payload["jti"])
      return render_unauthorized("token_not_found") if access_token.blank?

      token_digest = Digest::SHA256.hexdigest(token)
      return render_unauthorized("token_mismatch") unless ActiveSupport::SecurityUtils.secure_compare(access_token.token_digest, token_digest)

      @current_user = access_token.user
      @current_account = access_token.account
    rescue JWT::DecodeError
      render_unauthorized("invalid_token")
    end

    def bearer_token
      auth = request.headers["Authorization"].to_s
      match = auth.match(/^Bearer\s+(.+)$/)
      match && match[1]
    end

    def decode_jwt(token)
      secret = ENV["JWT_SECRET"].to_s
      return nil if secret.empty?

      payload, = JWT.decode(token, secret, true, { algorithm: "HS256" })
      payload
    end

    def render_unauthorized(reason)
      render json: { error: "unauthorized", reason: reason }, status: :unauthorized
    end
  end
end
