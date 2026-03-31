require "test_helper"

module Api
  module V1
    class ServicesControllerTest < ActionDispatch::IntegrationTest
      setup do
        @account = create_account
        @user = create_user(account: @account)
        @service = create_service(account: @account, name: "API Service", slug: "api-service")
      end

      test "returns unauthorized without bearer token" do
        get "/api/v1/services"

        assert_response :unauthorized
        assert_equal "missing_bearer_token", response.parsed_body["reason"]
      end

      test "returns unauthorized for invalid token" do
        with_env("JWT_SECRET" => "jwt-test-secret") do
          get "/api/v1/services", headers: { "Authorization" => "Bearer invalid" }
        end

        assert_response :unauthorized
        assert_equal "invalid_token", response.parsed_body["reason"]
      end

      test "returns unauthorized when token jti does not exist" do
        with_env("JWT_SECRET" => "jwt-test-secret") do
          token = JWT.encode(
            {
              sub: @user.id,
              acc: @account.id,
              jti: SecureRandom.uuid,
              iat: Time.current.to_i,
              exp: 15.minutes.from_now.to_i
            },
            "jwt-test-secret",
            "HS256"
          )

          get "/api/v1/services", headers: { "Authorization" => "Bearer #{token}" }
        end

        assert_response :unauthorized
        assert_equal "token_not_found", response.parsed_body["reason"]
      end

      test "returns unauthorized when token digest does not match" do
        with_env("JWT_SECRET" => "jwt-test-secret") do
          token = issue_access_token
          payload, = JWT.decode(token, "jwt-test-secret", true, { algorithm: "HS256" })
          ApiAccessToken.find_by!(jti: payload["jti"]).update!(token_digest: Digest::SHA256.hexdigest("different-token"))

          get "/api/v1/services", headers: { "Authorization" => "Bearer #{token}" }
        end

        assert_response :unauthorized
        assert_equal "token_mismatch", response.parsed_body["reason"]
      end

      test "returns services for valid token" do
        with_env("JWT_SECRET" => "jwt-test-secret") do
          token = issue_access_token

          get "/api/v1/services", headers: { "Authorization" => "Bearer #{token}" }
        end

        assert_response :success
        service_names = response.parsed_body.fetch("services").map { |item| item["name"] }
        assert_includes service_names, "API Service"
      end

      private

      def issue_access_token
        api_client = ApiClient.create!(account: @account, name: "tests-client")
        Api::TokenIssuer.new(secret: "jwt-test-secret").issue!(user: @user, api_client: api_client)[:access_token]
      end
    end
  end
end
