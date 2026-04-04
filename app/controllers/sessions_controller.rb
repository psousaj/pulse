class SessionsController < ApplicationController
  def new
    redirect_to root_path if logged_in?
  end

  def start
    return redirect_to(login_path, alert: "Keycloak OIDC is not configured. Set KEYCLOAK_* first.") unless oidc_configured?

    state = SecureRandom.hex(24)
    nonce = SecureRandom.hex(24)
    session[:oidc_state] = state
    session[:oidc_nonce] = nonce

    redirect_to Auth::OidcClient.new.login_url(state:, nonce:), allow_other_host: true
  end

  def create
    if params[:error].present?
      return redirect_to(login_path, alert: params[:error_description].presence || params[:error].to_s.humanize)
    end

    expected_state = session.delete(:oidc_state).to_s
    provided_state = params[:state].to_s
    if expected_state.empty? || provided_state.empty? || !ActiveSupport::SecurityUtils.secure_compare(expected_state, provided_state)
      return redirect_to(login_path, alert: "Invalid authentication state. Please try again.")
    end

    token_response = Auth::OidcClient.new.exchange_code_for_token(code: params[:code].to_s)
    claims = persist_auth_session!(token_response)

    expected_nonce = session.delete(:oidc_nonce).to_s
    if expected_nonce.present? && claims["nonce"].to_s != expected_nonce
      clear_auth_session!
      return redirect_to(login_path, alert: "Invalid authentication nonce. Please try again.")
    end

    unless current_account.present?
      clear_auth_session!
      return redirect_to(login_path, alert: "The account from your Keycloak token is not available in Pulse.")
    end

    redirect_to root_path, notice: "Signed in successfully"
  rescue Auth::AuthenticationError => error
    clear_auth_session!
    redirect_to login_path, alert: error.message
  end

  def destroy
    logout_url = oidc_configured? ? Auth::OidcClient.new.logout_url(id_token_hint: load_auth_token_bundle[:id_token].to_s) : nil
    clear_auth_session!

    if logout_url.present?
      redirect_to logout_url, allow_other_host: true
    else
      redirect_to login_path, notice: "Signed out"
    end
  end
end
