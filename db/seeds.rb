HealthCheckType.find_or_create_by!(key: "http") do |type|
  type.name = "HTTP Endpoint"
  type.runner_class = "CheckRunners::HttpRunner"
end

[
  [ "tcp", "TCP Port", "CheckRunners::TcpRunner" ],
  [ "ssl", "SSL Expiration", "CheckRunners::SslRunner" ],
  [ "dns", "DNS Resolution", "CheckRunners::DnsRunner" ],
  [ "heartbeat", "Heartbeat", "CheckRunners::HeartbeatRunner" ],
  [ "webhook", "Webhook Validation", "CheckRunners::WebhookRunner" ],
  [ "synthetic", "Synthetic Browser", "CheckRunners::SyntheticRunner" ]
].each do |key, name, runner_class|
  HealthCheckType.find_or_create_by!(key: key) do |type|
    type.name = name
    type.runner_class = runner_class
  end
end

Setting.find_or_create_by!(account_id: nil, namespace: "alerts", key: "reminder_interval_minutes") do |setting|
  setting.value_json = { value: 10 }
end
