require "test_helper"

module Api
  class TokenIssuerTest < ActiveSupport::TestCase
    setup do
      @account = create_account
      @user = create_user(account: @account)
      @api_client = ApiClient.create!(account: @account, name: "bot")
    end

    test "issues access and refresh tokens with persisted digests" do
      with_env("JWT_SECRET" => "issuer-secret") do
        assert_difference "ApiAccessToken.count", 1 do
          assert_difference "ApiRefreshToken.count", 1 do
            @tokens = Api::TokenIssuer.new.issue!(user: @user, api_client: @api_client, scopes: %w[services:read])
          end
        end

        assert @tokens[:access_token].present?
        assert @tokens[:refresh_token].present?

        access_payload, = JWT.decode(@tokens[:access_token], "issuer-secret", true, { algorithm: "HS256" })
        refresh_payload, = JWT.decode(@tokens[:refresh_token], "issuer-secret", true, { algorithm: "HS256" })

        access_record = ApiAccessToken.find_by!(jti: access_payload["jti"])
        refresh_record = ApiRefreshToken.find_by!(jti: refresh_payload["jti"])

        assert_equal Digest::SHA256.hexdigest(@tokens[:access_token]), access_record.token_digest
        assert_equal Digest::SHA256.hexdigest(@tokens[:refresh_token]), refresh_record.token_digest
        assert_equal @user.id, access_payload["sub"]
        assert_equal @account.id, access_payload["acc"]
      end
    end

    test "raises when jwt secret is missing" do
      error = assert_raises(ArgumentError) do
        Api::TokenIssuer.new(secret: "").issue!(user: @user, api_client: @api_client)
      end

      assert_equal "JWT_SECRET is missing", error.message
    end
  end
end
