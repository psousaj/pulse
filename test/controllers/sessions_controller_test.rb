require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "login page explains when keycloak oidc is not configured" do
    with_env(
      "KEYCLOAK_PUBLIC_BASE_URL" => nil,
      "KEYCLOAK_INTERNAL_BASE_URL" => nil,
      "KEYCLOAK_REALM" => nil,
      "KEYCLOAK_WEB_CLIENT_ID" => nil,
      "KEYCLOAK_WEB_CLIENT_SECRET" => nil,
      "KEYCLOAK_REDIRECT_URI" => nil
    ) do
      get "/login"
    end

    assert_response :success
    assert_match "Keycloak OIDC is not configured", response.body
    assert_match "KEYCLOAK_PUBLIC_BASE_URL", response.body
  end

  test "login entrypoint redirects to keycloak authorize endpoint" do
    with_keycloak_env do
      post "/login"
    end

    assert_response :redirect
    assert_match %r{\Ahttp://localhost:8081/realms/pulse/protocol/openid-connect/auth}, response.redirect_url
    assert_match "client_id=pulse-web", response.redirect_url
    assert_match "response_type=code", response.redirect_url
  end

  test "callback establishes a web session from keycloak tokens" do
    account = create_account(slug: "personal")

    with_keycloak_env do
      with_stubbed_keycloak_jwks do
        post "/login"
        redirect_uri = URI.parse(response.redirect_url)
        params = Rack::Utils.parse_query(redirect_uri.query)
        token_response = build_keycloak_session_tokens(account: account, permissions: %w[monitor.read admin], nonce: params.fetch("nonce"))

        with_temporary_instance_method(Auth::OidcClient, :exchange_code_for_token, ->(code:) { token_response }) do
          get "/callback", params: { code: "pulse-test-code", state: params.fetch("state") }
        end
      end
    end

    assert_redirected_to "/"
  end
end
