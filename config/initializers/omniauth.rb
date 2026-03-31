Rails.application.config.middleware.use OmniAuth::Builder do
  github_client_id = ENV["GITHUB_CLIENT_ID"].to_s
  github_client_secret = ENV["GITHUB_CLIENT_SECRET"].to_s

  if github_client_id.present? && github_client_secret.present?
    provider :github, github_client_id, github_client_secret, scope: "read:user,user:email"
  end
end

OmniAuth.config.allowed_request_methods = %i[get post]
OmniAuth.config.silence_get_warning = true
