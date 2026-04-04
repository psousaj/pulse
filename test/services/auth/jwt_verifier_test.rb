require "test_helper"

module Auth
  class JwtVerifierTest < ActiveSupport::TestCase
    test "verifies a valid RS256 token against jwks" do
      with_keycloak_env do
        with_stubbed_keycloak_jwks do
          token = issue_keycloak_token(audience: ENV.fetch("KEYCLOAK_API_AUDIENCE"), account_slug: "personal", permissions: %w[monitor.read])
          payload = JwtVerifier.new(expected_audience: ENV.fetch("KEYCLOAK_API_AUDIENCE")).verify!(token)

          assert_equal "personal", payload.fetch("pulse_account_slug")
          assert_equal [ "monitor.read" ], payload.fetch("pulse_permissions")
        end
      end
    end

    test "rejects a token with the wrong audience" do
      with_keycloak_env do
        with_stubbed_keycloak_jwks do
          token = issue_keycloak_token(audience: "wrong-audience", account_slug: "personal", permissions: %w[monitor.read])

          assert_raises(AuthenticationError) do
            JwtVerifier.new(expected_audience: ENV.fetch("KEYCLOAK_API_AUDIENCE")).verify!(token)
          end
        end
      end
    end

    test "rejects an expired token" do
      with_keycloak_env do
        with_stubbed_keycloak_jwks do
          token = issue_keycloak_token(audience: ENV.fetch("KEYCLOAK_API_AUDIENCE"), account_slug: "personal", permissions: %w[monitor.read], expires_at: 1.minute.ago)

          assert_raises(AuthenticationError) do
            JwtVerifier.new(expected_audience: ENV.fetch("KEYCLOAK_API_AUDIENCE")).verify!(token)
          end
        end
      end
    end
  end
end