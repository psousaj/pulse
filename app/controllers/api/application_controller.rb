module Api
  class ApplicationController < ActionController::API
    before_action :authenticate_api_request!
    rescue_from Auth::ForbiddenError, with: :render_forbidden

    private

    attr_reader :current_account, :current_user

    def authenticate_api_request!
      token = bearer_token
      return render_unauthorized("missing_bearer_token") if token.blank?

      payload = Auth::JwtVerifier.new(expected_audience: Auth::Settings.api_audience).verify!(token)
      principal = Auth::Principal.from_payload(payload, access_token: token)
      account = Account.find_by(slug: principal.account_slug)
      return render_unauthorized("unknown_account") if account.blank?

      Current.user = principal
      Current.account = account
      @current_user = principal
      @current_account = account
    rescue Auth::AuthenticationError
      render_unauthorized("invalid_token")
    end

    def require_permissions!(*permissions)
      Auth::Authorization.require_any_permission!(permissions.flatten, principal: current_user)
    end

    def bearer_token
      auth = request.headers["Authorization"].to_s
      match = auth.match(/^Bearer\s+(.+)$/)
      match && match[1]
    end

    def render_unauthorized(reason)
      render json: { error: "unauthorized", reason: reason }, status: :unauthorized
    end

    def render_forbidden(_error)
      render json: { error: "forbidden", reason: "insufficient_permissions" }, status: :forbidden
    end
  end
end
