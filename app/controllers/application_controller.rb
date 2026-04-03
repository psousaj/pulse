class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :current_account, :logged_in?, :github_oauth_configured?

  private

  def current_user
    return nil if session[:user_id].blank?

    @current_user ||= User.find_by(id: session[:user_id], active: true)
  end

  def current_account
    current_user&.account
  end

  def logged_in?
    current_user.present?
  end

  def github_oauth_configured?
    ENV["GITHUB_CLIENT_ID"].present? && ENV["GITHUB_CLIENT_SECRET"].present?
  end

  def require_login
    return if logged_in?

    message = if github_oauth_configured?
      "Please login with GitHub."
    else
      "GitHub OAuth is not configured. Set GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET first."
    end

    redirect_to login_path, alert: message
  end
end
