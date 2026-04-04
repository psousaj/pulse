module Auth
  class JwtVerifier
    DEFAULT_ALGORITHMS = [ "RS256" ].freeze

    def initialize(expected_audience: nil)
      @expected_audience = expected_audience
    end

    def verify!(token)
      decode(token)
    rescue JWT::DecodeError => error
      begin
        decode(token, force_refresh: true)
      rescue JWT::DecodeError => refresh_error
        raise AuthenticationError, refresh_error.message
      end
    end

    private

    attr_reader :expected_audience

    def decode(token, force_refresh: false)
      payload, = JWT.decode(token, nil, true, decode_options(force_refresh:))
      payload
    end

    def decode_options(force_refresh:)
      {
        algorithms: DEFAULT_ALGORITHMS,
        verify_expiration: true,
        verify_iat: true,
        verify_not_before: true,
        verify_iss: true,
        iss: Settings.issuer,
        verify_aud: expected_audience.present?,
        aud: expected_audience,
        jwks: ->(_options) { JwksCache.fetch(force: force_refresh) }
      }
    end
  end
end