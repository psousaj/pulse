require "digest"

module Api
  class TokenIssuer
    ACCESS_TTL = 15.minutes
    REFRESH_TTL = 30.days

    def initialize(secret: ENV["JWT_SECRET"].to_s)
      @secret = secret
    end

    def issue!(user:, api_client:, scopes: [])
      raise ArgumentError, "JWT_SECRET is missing" if secret.empty?

      now = Time.current
      account = user.account

      access_jti = SecureRandom.uuid
      access_payload = {
        sub: user.id,
        acc: account.id,
        jti: access_jti,
        scopes: scopes,
        iat: now.to_i,
        exp: (now + ACCESS_TTL).to_i
      }
      access_token = JWT.encode(access_payload, secret, "HS256")

      refresh_jti = SecureRandom.uuid
      refresh_payload = {
        sub: user.id,
        acc: account.id,
        jti: refresh_jti,
        type: "refresh",
        iat: now.to_i,
        exp: (now + REFRESH_TTL).to_i
      }
      refresh_token = JWT.encode(refresh_payload, secret, "HS256")

      ApiAccessToken.create!(
        account: account,
        user: user,
        api_client: api_client,
        jti: access_jti,
        token_digest: Digest::SHA256.hexdigest(access_token),
        scopes_json: scopes,
        expires_at: now + ACCESS_TTL
      )

      ApiRefreshToken.create!(
        account: account,
        user: user,
        api_client: api_client,
        jti: refresh_jti,
        token_digest: Digest::SHA256.hexdigest(refresh_token),
        expires_at: now + REFRESH_TTL
      )

      {
        access_token: access_token,
        refresh_token: refresh_token,
        expires_at: now + ACCESS_TTL,
        refresh_expires_at: now + REFRESH_TTL
      }
    end

    private

    attr_reader :secret
  end
end
