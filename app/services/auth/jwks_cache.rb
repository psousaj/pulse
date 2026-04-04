require "json"
require "net/http"

module Auth
  module JwksCache
    CACHE_KEY = "auth:keycloak:jwks".freeze
    TTL = 10.minutes

    module_function

    def fetch(force: false)
      Rails.cache.fetch(CACHE_KEY, expires_in: TTL, force:) do
        response = Net::HTTP.get_response(URI(Settings.jwks_endpoint))
        raise AuthenticationError, "Unable to fetch Keycloak JWKS (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      end
    end
  end
end