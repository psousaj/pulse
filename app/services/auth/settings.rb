module Auth
  module Settings
    module_function

    def public_base_url
      ENV["KEYCLOAK_PUBLIC_BASE_URL"].to_s.chomp("/")
    end

    def internal_base_url
      ENV.fetch("KEYCLOAK_INTERNAL_BASE_URL", public_base_url).to_s.chomp("/")
    end

    def realm
      ENV.fetch("KEYCLOAK_REALM", "pulse").to_s
    end

    def issuer
      return "" if public_base_url.empty?

      "#{public_base_url}/realms/#{realm}"
    end

    def authorization_endpoint
      return "" if issuer.empty?

      "#{issuer}/protocol/openid-connect/auth"
    end

    def token_endpoint
      return "" if internal_base_url.empty?

      "#{internal_base_url}/realms/#{realm}/protocol/openid-connect/token"
    end

    def jwks_endpoint
      return "" if internal_base_url.empty?

      "#{internal_base_url}/realms/#{realm}/protocol/openid-connect/certs"
    end

    def logout_endpoint
      return "" if issuer.empty?

      "#{issuer}/protocol/openid-connect/logout"
    end

    def web_client_id
      ENV["KEYCLOAK_WEB_CLIENT_ID"].to_s
    end

    def web_client_secret
      ENV["KEYCLOAK_WEB_CLIENT_SECRET"].to_s
    end

    def web_scopes
      ENV.fetch("KEYCLOAK_WEB_SCOPES", "openid profile email offline_access").to_s
    end

    def redirect_uri
      ENV["KEYCLOAK_REDIRECT_URI"].to_s
    end

    def post_logout_redirect_uri
      ENV.fetch("KEYCLOAK_POST_LOGOUT_REDIRECT_URI", redirect_uri.presence || default_post_logout_redirect_uri).to_s
    end

    def default_post_logout_redirect_uri
      app_url = ENV.fetch("PULSE_PUBLIC_BASE_URL", "http://localhost:3000").to_s.chomp("/")
      "#{app_url}/login"
    end

    def api_audience
      ENV.fetch("KEYCLOAK_API_AUDIENCE", "pulse-api").to_s
    end

    def account_claim
      ENV.fetch("KEYCLOAK_ACCOUNT_CLAIM", "pulse_account_slug").to_s
    end

    def permissions_claim
      ENV.fetch("KEYCLOAK_PERMISSIONS_CLAIM", "pulse_permissions").to_s
    end

    def bot_client_id
      ENV["KEYCLOAK_BOT_CLIENT_ID"].to_s
    end

    def bot_client_secret
      ENV["KEYCLOAK_BOT_CLIENT_SECRET"].to_s
    end

    def oidc_configured?
      [ public_base_url, internal_base_url, realm, web_client_id, web_client_secret, redirect_uri ].all?(&:present?)
    end

    def bot_credentials_configured?
      [ internal_base_url, realm, bot_client_id, bot_client_secret ].all?(&:present?)
    end
  end
end
