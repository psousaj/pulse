class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :hydrate_web_session

  helper_method :current_user, :current_account, :current_permissions, :logged_in?, :oidc_configured?

  rescue_from Auth::ForbiddenError, with: :handle_forbidden

  private

  def current_user
    hydrate_web_session unless defined?(@current_user)
    @current_user
  end

  def current_account
    hydrate_web_session unless defined?(@current_user)
    return @current_account if defined?(@current_account)
    return nil if current_user.blank?

    @current_account = Account.find_by(slug: current_user.account_slug)
    Current.account = @current_account
    @current_account
  end

  def logged_in?
    current_user.present? && current_account.present?
  end

  def current_permissions
    current_user&.permissions || []
  end

  def oidc_configured?
    Auth::Settings.oidc_configured?
  end

  def require_login
    return if logged_in?

    store_return_location!

    message = if oidc_configured?
      "Please sign in with Keycloak."
    else
      "Keycloak OIDC is not configured. Set KEYCLOAK_* first."
    end

    redirect_to login_path, alert: message
  end

  def require_permissions!(*permissions)
    Auth::Authorization.require_any_permission!(permissions.flatten, principal: current_user)
  end

  def persist_auth_session!(token_response)
    expires_at = Time.current + token_response.fetch("expires_in", 300).to_i.seconds
    id_token = token_response["id_token"].presence || token_response["access_token"].to_s
    claims = Auth::JwtVerifier.new(expected_audience: Auth::Settings.web_client_id).verify!(id_token)

    persist_auth_token_bundle!(
      access_token: token_response["access_token"].to_s,
      refresh_token: token_response["refresh_token"].to_s,
      id_token: token_response["id_token"].to_s
    )

    session[:auth_expires_at] = expires_at.to_i
    session[:auth_claims] = Auth::Principal.from_payload(claims).session_hash

    token_bundle = load_auth_token_bundle
    principal = Auth::Principal.from_payload(
      claims,
      access_token: token_bundle[:access_token],
      refresh_token: token_bundle[:refresh_token],
      id_token: token_bundle[:id_token],
      expires_at: expires_at
    )

    @current_user = principal
    @current_account = Account.find_by(slug: principal.account_slug)
    Current.user = principal
    Current.account = @current_account
    claims
  end

  def clear_auth_session!
    cache_key = session[:auth_token_cache_key].to_s
    Rails.cache.delete(auth_token_cache_key(cache_key)) if cache_key.present?

    session.delete(:auth_token_cache_key)
    session.delete(:auth_expires_at)
    session.delete(:auth_claims)
    session.delete(:oidc_state)
    session.delete(:oidc_nonce)
    session.delete(:post_login_path)
    @current_user = nil
    @current_account = nil
    Current.reset
  end

  def after_login_path
    session.delete(:post_login_path).presence || root_path
  end

  def store_return_location!
    return unless request.get?
    return if request.fullpath == login_path

    session[:post_login_path] = request.fullpath
  end

  def hydrate_web_session
    return @current_user if defined?(@current_user) && @current_user.present?

    Current.reset
    claims = session[:auth_claims]
    return @current_user = nil if claims.blank?

    refresh_web_session_if_needed!

    token_bundle = load_auth_token_bundle
    expires_at = session[:auth_expires_at].present? ? Time.zone.at(session[:auth_expires_at].to_i) : nil
    principal = Auth::Principal.from_session_hash(
      session[:auth_claims],
      access_token: token_bundle[:access_token],
      refresh_token: token_bundle[:refresh_token],
      id_token: token_bundle[:id_token],
      expires_at: expires_at
    )

    @current_user = principal
    @current_account = Account.find_by(slug: principal.account_slug)
    Current.user = principal
    Current.account = @current_account

    @current_user
  rescue Auth::AuthenticationError
    clear_auth_session!
    @current_user = nil
  end

  def refresh_web_session_if_needed!
    expires_at = session[:auth_expires_at].to_i
    return if expires_at <= 0
    return if Time.zone.at(expires_at) > 1.minute.from_now

    refresh_token = load_auth_token_bundle[:refresh_token].to_s
    raise Auth::AuthenticationError, "Your session expired. Please sign in again." if refresh_token.empty?

    token_response = Auth::OidcClient.new.refresh_session(refresh_token: refresh_token)
    persist_auth_session!(token_response)
  end

  def load_auth_token_bundle
    cache_key = session[:auth_token_cache_key].to_s
    return {} if cache_key.blank?

    Rails.cache.read(auth_token_cache_key(cache_key)).to_h.symbolize_keys
  end

  def persist_auth_token_bundle!(access_token:, refresh_token:, id_token:)
    cache_key = session[:auth_token_cache_key].presence || SecureRandom.uuid
    session[:auth_token_cache_key] = cache_key
    Rails.cache.write(
      auth_token_cache_key(cache_key),
      {
        access_token: access_token,
        refresh_token: refresh_token,
        id_token: id_token
      },
      expires_in: 30.days
    )
  end

  def auth_token_cache_key(cache_key)
    "auth:web_session:#{cache_key}"
  end

  def handle_forbidden(_error)
    redirect_back fallback_location: root_path, alert: "You do not have permission to perform that action."
  end
end
