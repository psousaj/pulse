require "test_helper"
require Rails.root.join("bot/main").to_s

class BotMainTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body, :success) do
    def is_a?(klass)
      return success if klass == Net::HTTPSuccess

      super
    end
  end

  class FakeHttpClient
    attr_accessor :use_ssl
    attr_reader :requests

    def initialize(*responses)
      @responses = responses.flatten
      @requests = []
    end

    def request(request)
      @requests << request
      @responses.length > 1 ? @responses.shift : @responses.first
    end
  end

  class StaticTokenProvider
    def initialize(token)
      @token = token
    end

    def token
      @token
    end
  end

  test "client credentials provider caches the bot token until it expires" do
    fake_http = FakeHttpClient.new(
      FakeResponse.new("200", { access_token: "bot-token", expires_in: 120 }.to_json, true)
    )

    with_temporary_class_method(Net::HTTP, :new, ->(_host, _port) { fake_http }) do
      provider = KeycloakClientCredentialsProvider.new(
        base_url: "http://keycloak:8080",
        realm: "pulse",
        client_id: "pulse-bot",
        client_secret: "pulse-bot-secret"
      )

      assert_equal "bot-token", provider.token
      assert_equal "bot-token", provider.token
    end

    assert_equal 1, fake_http.requests.size
    assert_equal "application/x-www-form-urlencoded", fake_http.requests.first["Content-Type"]
  end

  test "client credentials provider refreshes when the cached token expires" do
    fake_http = FakeHttpClient.new(
      FakeResponse.new("200", { access_token: "bot-token-1", expires_in: 120 }.to_json, true),
      FakeResponse.new("200", { access_token: "bot-token-2", expires_in: 120 }.to_json, true)
    )

    provider = nil
    with_temporary_class_method(Net::HTTP, :new, ->(_host, _port) { fake_http }) do
      provider = KeycloakClientCredentialsProvider.new(
        base_url: "http://keycloak:8080",
        realm: "pulse",
        client_id: "pulse-bot",
        client_secret: "pulse-bot-secret"
      )

      assert_equal "bot-token-1", provider.token
      provider.instance_variable_set(:@expires_at, Time.now - 5)
      assert_equal "bot-token-2", provider.token
    end

    assert_equal 2, fake_http.requests.size
  end

  test "client credentials provider surfaces keycloak failures clearly" do
    fake_http = FakeHttpClient.new(
      FakeResponse.new("401", { error: "unauthorized_client" }.to_json, false)
    )

    with_temporary_class_method(Net::HTTP, :new, ->(_host, _port) { fake_http }) do
      provider = KeycloakClientCredentialsProvider.new(
        base_url: "http://keycloak:8080",
        realm: "pulse",
        client_id: "pulse-bot",
        client_secret: "bad-secret"
      )

      error = assert_raises(RuntimeError) do
        provider.token
      end

      assert_equal "Keycloak client credentials failed (401)", error.message
    end
  end

  test "bot api client sends the keycloak bearer token to the Pulse API" do
    fake_http = FakeHttpClient.new(
      FakeResponse.new("200", { services: [] }.to_json, true)
    )

    with_temporary_class_method(Net::HTTP, :new, ->(_host, _port) { fake_http }) do
      response = BotApiClient.new(
        base_url: "http://pulse.test",
        token_provider: StaticTokenProvider.new("oidc-bot-token")
      ).get("/api/v1/services")

      assert_equal 200, response[:code]
    end

    request = fake_http.requests.first
    assert_equal "Bearer oidc-bot-token", request["Authorization"]
  end
end
