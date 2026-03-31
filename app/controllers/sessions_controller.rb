class SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create

  def new
    redirect_to root_path if logged_in?
  end

  def create
    auth = request.env["omniauth.auth"]
    return redirect_to(login_path, alert: "GitHub authentication failed") if auth.blank?

    account = Account.first_or_create!(
      name: ENV.fetch("DEFAULT_ACCOUNT_NAME", "Personal Account"),
      slug: ENV.fetch("DEFAULT_ACCOUNT_SLUG", "personal")
    )

    user = account.users.find_or_initialize_by(github_uid: auth["uid"].to_s)
    user.email = auth.dig("info", "email").presence || "#{auth.dig('info', 'nickname')}@users.noreply.github.com"
    user.name = auth.dig("info", "name").presence || auth.dig("info", "nickname").presence || "GitHub User"
    user.role = "owner" if user.role.blank?
    user.active = true
    user.last_login_at = Time.current
    user.save!

    session[:user_id] = user.id
    redirect_to root_path, notice: "Signed in successfully"
  rescue ActiveRecord::RecordInvalid => error
    redirect_to login_path, alert: "Login failed: #{error.record.errors.full_messages.join(', ')}"
  end

  def failure
    redirect_to login_path, alert: "GitHub authentication failed"
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "Signed out"
  end
end
