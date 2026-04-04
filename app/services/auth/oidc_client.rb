require "json"
require "net/http"

module Auth
  class OidcClient
    def login_url(state:, nonce:)
      query = {
        client_id: Settings.web_client_id,
        redirect_uri: Settings.redirect_uri,
        response_type: "code",
        response_mode: "query",
        scope: Settings.web_scopes,
        state: state,
        nonce: nonce
      }

      uri = URI(Settings.authorization_endpoint)
      uri.query = query.to_query
      uri.to_s
    end

    def exchange_code_for_token(code:)
      post_form(
        Settings.token_endpoint,
        grant_type: "authorization_code",
        code: code,
        client_id: Settings.web_client_id,
        client_secret: Settings.web_client_secret,
        redirect_uri: Settings.redirect_uri
      )
    end

    def refresh_session(refresh_token:)
      post_form(
        Settings.token_endpoint,
        grant_type: "refresh_token",
        refresh_token: refresh_token,
        client_id: Settings.web_client_id,
        client_secret: Settings.web_client_secret
      )
    end

    def client_credentials_token(client_id:, client_secret:)
      post_form(
        Settings.token_endpoint,
        grant_type: "client_credentials",
        client_id: client_id,
        client_secret: client_secret
      )
    end

    def logout_url(id_token_hint: nil)
      uri = URI(Settings.logout_endpoint)
      params = {
        post_logout_redirect_uri: Settings.post_logout_redirect_uri,
        client_id: Settings.web_client_id
      }
      params[:id_token_hint] = id_token_hint if id_token_hint.present?
      uri.query = params.to_query
      uri.to_s
    end

    private

    def post_form(url, params)
      uri = URI(url)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/x-www-form-urlencoded"
      request.set_form_data(params)

      response = http_client_for(uri).request(request)
      body = JSON.parse(response.body)
      raise AuthenticationError, body["error_description"].presence || body["error"].presence || "Keycloak token exchange failed" unless response.is_a?(Net::HTTPSuccess)

      body
    rescue JSON::ParserError => error
      raise AuthenticationError, "Keycloak returned an invalid token payload"
    rescue StandardError => error
      raise error if error.is_a?(AuthenticationError)

      raise AuthenticationError, error.message
    end

    def http_client_for(uri)
      Net::HTTP.tap do |http|
        http.new(uri.host, uri.port).tap do |client|
          client.use_ssl = (uri.scheme == "https")
          return client
        end
      end
    end
  end
end