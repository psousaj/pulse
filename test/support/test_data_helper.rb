module TestDataHelper
  def with_temporary_class_method(klass, method_name, replacement)
    singleton = klass.singleton_class
    backup_name = "__pulse_test_original_#{method_name}"
    had_original = singleton.method_defined?(method_name) || singleton.private_method_defined?(method_name)

    singleton.alias_method(backup_name, method_name) if had_original
    klass.define_singleton_method(method_name, replacement)

    yield
  ensure
    if had_original
      singleton.alias_method(method_name, backup_name)
      singleton.remove_method(backup_name)
    else
      singleton.remove_method(method_name)
    end
  end

  def with_temporary_instance_method(klass, method_name, replacement)
    backup_name = "__pulse_test_original_instance_#{method_name}"
    had_original = klass.instance_methods(false).include?(method_name) || klass.private_instance_methods(false).include?(method_name)

    klass.alias_method(backup_name, method_name) if had_original
    klass.define_method(method_name, replacement)

    yield
  ensure
    if had_original
      klass.alias_method(method_name, backup_name)
      klass.remove_method(backup_name)
    else
      klass.remove_method(method_name)
    end
  end

  def with_env(overrides)
    previous = {}
    overrides.each do |key, value|
      previous[key] = ENV[key]
      ENV[key] = value
    end

    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end

  def with_keycloak_env(overrides = {})
    defaults = {
      "KEYCLOAK_PUBLIC_BASE_URL" => "http://localhost:8081",
      "KEYCLOAK_INTERNAL_BASE_URL" => "http://localhost:8081",
      "KEYCLOAK_REALM" => "pulse",
      "KEYCLOAK_WEB_CLIENT_ID" => "pulse-web",
      "KEYCLOAK_WEB_CLIENT_SECRET" => "pulse-web-secret",
      "KEYCLOAK_BOT_CLIENT_ID" => "pulse-bot",
      "KEYCLOAK_BOT_CLIENT_SECRET" => "pulse-bot-secret",
      "KEYCLOAK_API_AUDIENCE" => "pulse-api",
      "KEYCLOAK_ACCOUNT_CLAIM" => "pulse_account_slug",
      "KEYCLOAK_PERMISSIONS_CLAIM" => "pulse_permissions",
      "KEYCLOAK_REDIRECT_URI" => "http://localhost:3000/callback",
      "KEYCLOAK_POST_LOGOUT_REDIRECT_URI" => "http://localhost:3000/login",
      "PULSE_PUBLIC_BASE_URL" => "http://localhost:3000"
    }

    with_env(defaults.merge(overrides)) { yield }
  end

  def with_stubbed_keycloak_jwks
    jwks = keycloak_jwks

    with_temporary_class_method(Auth::JwksCache, :fetch, ->(force: false) { jwks }) do
      yield
    end
  end

  def keycloak_signing_key
    @keycloak_signing_key ||= OpenSSL::PKey::RSA.generate(2048)
  end

  def keycloak_signing_kid
    @keycloak_signing_kid ||= "pulse-test-kid"
  end

  def keycloak_jwks
    @keycloak_jwks ||= { keys: [ JWT::JWK.new(keycloak_signing_key.public_key, kid: keycloak_signing_kid).export ] }
  end

  def issue_keycloak_token(audience:, account_slug:, permissions:, subject: "subject-#{SecureRandom.hex(4)}", username: "operator", email: "operator@example.com", nonce: nil, expires_at: 15.minutes.from_now, additional_claims: {})
    now = Time.current
    payload = {
      "iss" => "#{ENV.fetch('KEYCLOAK_PUBLIC_BASE_URL')}/realms/#{ENV.fetch('KEYCLOAK_REALM')}",
      "aud" => audience,
      "sub" => subject,
      "preferred_username" => username,
      "email" => email,
      ENV.fetch("KEYCLOAK_ACCOUNT_CLAIM", "pulse_account_slug") => account_slug,
      ENV.fetch("KEYCLOAK_PERMISSIONS_CLAIM", "pulse_permissions") => permissions,
      "iat" => now.to_i,
      "nbf" => now.to_i,
      "exp" => expires_at.to_i,
      "jti" => SecureRandom.uuid
    }.merge(additional_claims)
    payload["nonce"] = nonce if nonce.present?

    JWT.encode(payload, keycloak_signing_key, "RS256", kid: keycloak_signing_kid)
  end

  def build_keycloak_session_tokens(account:, permissions:, nonce:, subject: "subject-#{SecureRandom.hex(4)}", username: "operator", email: "operator@example.com")
    {
      "access_token" => issue_keycloak_token(
        audience: ENV.fetch("KEYCLOAK_API_AUDIENCE"),
        account_slug: account.slug,
        permissions: permissions,
        subject: subject,
        username: username,
        email: email
      ),
      "id_token" => issue_keycloak_token(
        audience: ENV.fetch("KEYCLOAK_WEB_CLIENT_ID"),
        account_slug: account.slug,
        permissions: permissions,
        subject: subject,
        username: username,
        email: email,
        nonce: nonce
      ),
      "refresh_token" => "refresh-#{SecureRandom.hex(8)}",
      "expires_in" => 3600
    }
  end

  def with_keycloak_login(account:, permissions:, subject: "subject-#{SecureRandom.hex(4)}", username: "operator", email: "operator@example.com")
    with_keycloak_env do
      with_stubbed_keycloak_jwks do
        post "/login"
        redirect_uri = URI.parse(response.redirect_url)
        params = Rack::Utils.parse_query(redirect_uri.query)
        token_response = build_keycloak_session_tokens(
          account: account,
          permissions: permissions,
          nonce: params.fetch("nonce"),
          subject: subject,
          username: username,
          email: email
        )

        with_temporary_instance_method(Auth::OidcClient, :exchange_code_for_token, ->(code:) { token_response }) do
          get "/callback", params: { code: "pulse-test-code", state: params.fetch("state") }
        end

        yield
      end
    end
  end

  def github_auth_hash(uid: "github-#{SecureRandom.hex(4)}", email: "owner-#{SecureRandom.hex(4)}@example.com", name: "GitHub User", nickname: "pulse-user")
    {
      "provider" => "github",
      "uid" => uid,
      "info" => {
        "email" => email,
        "name" => name,
        "nickname" => nickname
      }
    }
  end

  def issue_api_access_token(account:, user:, secret: "jwt-test-secret")
    api_client = ApiClient.create!(account: account, name: "tests-client-#{SecureRandom.hex(3)}")
    Api::TokenIssuer.new(secret: secret).issue!(user: user, api_client: api_client)[:access_token]
  end

  def create_account(name: "Test Account", slug: "test-account-#{SecureRandom.hex(4)}")
    Account.create!(
      name: name,
      slug: slug,
      timezone: "UTC",
      default_alert_interval_minutes: 10
    )
  end

  def create_user(account:, email: "user-#{SecureRandom.hex(4)}@example.com", role: "owner")
    User.create!(
      account: account,
      email: email,
      name: "Test User",
      role: role,
      active: true
    )
  end

  def create_service(account:, name: "Service #{SecureRandom.hex(3)}", slug: "service-#{SecureRandom.hex(4)}")
    Service.create!(
      account: account,
      name: name,
      slug: slug,
      visibility: "private",
      current_status: "operational"
    )
  end

  def create_monitor(account:, service: nil, name: "Monitor #{SecureRandom.hex(3)}", slug: "monitor-#{SecureRandom.hex(4)}", strategy: "http_polling", interval_seconds: 60, config_json: { "url" => "https://example.com/health" })
    PulseMonitor.create!(
      account: account,
      service: service,
      name: name,
      slug: slug,
      strategy: strategy,
      interval_seconds: interval_seconds,
      enabled: true,
      config_json: config_json
    )
  end

  def create_health_event(monitor:, account: monitor.account, service: monitor.service, monitor_source_binding: nil, source: "internal", status: "up", authoritative: true, checked_at: Time.current, error_message: nil, metadata_json: {})
    HealthEvent.create!(
      account: account,
      service: service,
      monitor: monitor,
      monitor_source_binding: monitor_source_binding,
      source: source,
      status: status,
      authoritative: authoritative,
      error_message: error_message,
      metadata_json: metadata_json,
      checked_at: checked_at
    )
  end

  def create_integration_endpoint(account:, provider: "zabbix", name: "#{provider}-#{SecureRandom.hex(3)}")
    IntegrationEndpoint.create!(
      account: account,
      provider: provider,
      name: name,
      enabled: true
    )
  end

  def create_monitor_source_binding(monitor:, kind: "integration", role: "primary", integration_endpoint: nil, external_ref: "external-#{SecureRandom.hex(3)}", token_digest: nil, config_json: {})
    MonitorSourceBinding.create!(
      account: monitor.account,
      monitor: monitor,
      integration_endpoint: integration_endpoint,
      kind: kind,
      provider: integration_endpoint&.provider,
      role: role,
      external_ref: external_ref,
      token_digest: token_digest,
      enabled: true,
      config_json: config_json
    )
  end

  def create_monitor_incident(monitor:, service: monitor.service, severity: "down", opened_at: Time.current)
    Incident.create!(
      account: monitor.account,
      service: service,
      monitor: monitor,
      state: "open",
      severity: severity,
      title: "#{monitor.name} #{severity}",
      trigger_kind: "check_failure",
      opened_at: opened_at
    )
  end

  def http_check_type
    HealthCheckType.find_or_create_by!(key: "http") do |type|
      type.name = "HTTP"
      type.runner_class = "CheckRunners::HttpRunner"
      type.enabled = true
      type.config_schema_version = 1
    end
  end

  def create_service_check(service:, account: service.account, health_check_type: http_check_type, name: "Check #{SecureRandom.hex(3)}", config_json: { "url" => "https://example.com/health" })
    ServiceCheck.create!(
      account: account,
      service: service,
      health_check_type: health_check_type,
      name: name,
      enabled: true,
      critical: true,
      interval_seconds: 60,
      timeout_ms: 2000,
      config_json: config_json,
      consecutive_failures: 0,
      consecutive_successes: 0
    )
  end

  def create_check_result(service_check:, status: "up", latency_breached: false)
    now = Time.current
    CheckResult.create!(
      account: service_check.account,
      service: service_check.service,
      service_check: service_check,
      scheduled_at: now,
      started_at: now,
      finished_at: now + 1.second,
      duration_ms: 100,
      status: status,
      latency_breached: latency_breached,
      timed_out: false,
      metadata_json: {}
    )
  end
end
