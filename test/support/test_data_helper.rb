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
