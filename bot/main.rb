require "discordrb"
require "json"
require "net/http"
require "uri"

class KeycloakClientCredentialsProvider
  def initialize(base_url:, realm:, client_id:, client_secret:)
    @base_url = base_url.chomp("/")
    @realm = realm
    @client_id = client_id
    @client_secret = client_secret
  end

  def token
    refresh! if @access_token.to_s.empty? || token_expired?
    @access_token
  end

  private

  attr_reader :base_url, :realm, :client_id, :client_secret

  def token_expired?
    @expires_at.nil? || Time.now >= (@expires_at - 30)
  end

  def refresh!
    uri = URI("#{base_url}/realms/#{realm}/protocol/openid-connect/token")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/x-www-form-urlencoded"
    request.set_form_data(
      grant_type: "client_credentials",
      client_id: client_id,
      client_secret: client_secret
    )

    response = http_client_for(uri).request(request)
    body = JSON.parse(response.body)
    raise "Keycloak client credentials failed (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

    @access_token = body.fetch("access_token")
    @expires_at = Time.now + body.fetch("expires_in", 60).to_i
  rescue StandardError => error
    raise error if error.message.include?("Keycloak client credentials failed")

    raise "Unable to obtain Keycloak bot token: #{error.message}"
  end

  def http_client_for(uri)
    Net::HTTP.new(uri.host, uri.port).tap do |http|
      http.use_ssl = (uri.scheme == "https")
    end
  end
end

class BotApiClient
  def initialize(base_url:, token_provider: nil)
    @base_url = base_url
    @token_provider = token_provider
  end

  def get(path)
    request(:get, path)
  end

  def post(path, payload = nil)
    request(:post, path, payload)
  end

  private

  attr_reader :base_url, :token_provider

  def request(method, path, payload = nil)
    uri = URI.join(ensure_trailing_slash(base_url), strip_leading_slash(path))

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    request = build_request(method, uri, payload)

    response = http.request(request)
    body = response.body.to_s

    {
      code: response.code.to_i,
      body: body.empty? ? {} : JSON.parse(body)
    }
  rescue StandardError => error
    {
      code: 500,
      body: { "error" => "request_failed", "message" => error.message }
    }
  end

  def build_request(method, uri, payload)
    request = case method
    when :post
      Net::HTTP::Post.new(uri)
    else
      Net::HTTP::Get.new(uri)
    end

    request["Content-Type"] = "application/json"
    bearer = token_provider&.token
    request["Authorization"] = "Bearer #{bearer}" unless bearer.to_s.empty?
    request.body = payload.to_json if payload
    request
  end

  def ensure_trailing_slash(url)
    url.end_with?("/") ? url : "#{url}/"
  end

  def strip_leading_slash(path)
    path.sub(%r{^/}, "")
  end
end

class PulseDiscordBot
  def initialize
    @token = ENV["DISCORD_BOT_TOKEN"].to_s
    @client_id = ENV["DISCORD_BOT_CLIENT_ID"].to_s
    @prefix = ENV.fetch("DISCORD_PREFIX", "!")
    @allowlist = ENV.fetch("DISCORD_ALLOWLIST_USER_IDS", "").split(",").map(&:strip)
    @allowed_roles = ENV.fetch("DISCORD_ALLOWED_ROLE_IDS", "").split(",").map(&:strip)
    @token_provider = build_token_provider
    @api = BotApiClient.new(
      base_url: ENV.fetch("PULSE_API_BASE_URL", "http://web:3000"),
      token_provider: token_provider
    )
  end

  def run
    abort("DISCORD_BOT_TOKEN is required") if token.empty?
    abort("KEYCLOAK_BOT_CLIENT_ID, KEYCLOAK_BOT_CLIENT_SECRET, and KEYCLOAK_INTERNAL_BASE_URL or KEYCLOAK_PUBLIC_BASE_URL are required for bot API auth") if token_provider.nil?

    bot = Discordrb::Commands::CommandBot.new(
      token: token,
      client_id: parsed_client_id,
      prefix: prefix,
      intents: %i[server_messages]
    )

    register_prefix_commands(bot)
    register_application_commands(bot) if parsed_client_id

    puts "discord_bot_started=true"
    bot.run
  end

  private

  attr_reader :token, :client_id, :prefix, :allowlist, :allowed_roles, :api, :token_provider

  def build_token_provider
    client_id = ENV["KEYCLOAK_BOT_CLIENT_ID"].to_s
    client_secret = ENV["KEYCLOAK_BOT_CLIENT_SECRET"].to_s
    realm = ENV.fetch("KEYCLOAK_REALM", "pulse")
    base_url = ENV.fetch("KEYCLOAK_INTERNAL_BASE_URL", ENV.fetch("KEYCLOAK_PUBLIC_BASE_URL", ""))

    return nil if client_id.empty? || client_secret.empty? || base_url.to_s.empty?

    KeycloakClientCredentialsProvider.new(
      base_url: base_url,
      realm: realm,
      client_id: client_id,
      client_secret: client_secret
    )
  end

  def parsed_client_id
    value = client_id.to_i
    value.positive? ? value : nil
  end

  def register_prefix_commands(bot)
    bot.command(:status) do |_event, service_slug|
      service_slug ? status_for_service(service_slug) : global_status
    end

    bot.command(:incidents) do |_event|
      active_incidents
    end

    bot.command(:uptime) do |_event, service_slug|
      uptime_for(service_slug)
    end

    bot.command(:ack) do |event, incident_id|
      mutate_guard(event) { placeholder_mutation("ack", incident_id: incident_id) }
    end

    bot.command(:mute) do |event, service_slug|
      mutate_guard(event) { placeholder_mutation("mute", service: service_slug) }
    end

    bot.command(:unmute) do |event, service_slug|
      mutate_guard(event) { placeholder_mutation("unmute", service: service_slug) }
    end

    bot.command(:pause) do |event, check_id|
      mutate_guard(event) { placeholder_mutation("pause", check_id: check_id) }
    end

    bot.command(:resume) do |event, check_id|
      mutate_guard(event) { placeholder_mutation("resume", check_id: check_id) }
    end
  end

  def register_application_commands(bot)
    bot.register_application_command(:status, "Show service status") do |cmd|
      cmd.string("service", "Service slug", required: false)
    end

    bot.register_application_command(:incidents, "List recent incidents")

    bot.register_application_command(:uptime, "Show uptime for a service") do |cmd|
      cmd.string("service", "Service slug", required: true)
    end

    bot.application_command(:status) do |event|
      service_slug = event.options["service"]
      event.respond(service_slug ? status_for_service(service_slug) : global_status)
    end

    bot.application_command(:incidents) do |event|
      event.respond(active_incidents)
    end

    bot.application_command(:uptime) do |event|
      event.respond(uptime_for(event.options["service"]))
    end
  end

  def global_status
    response = api.get("/api/v1/services")
    return "Status unavailable (#{response[:code]})" unless response[:code] == 200

    services = response[:body]["services"] || []
    return "No services found." if services.empty?

    grouped = services.group_by { |service| service["status"] }
    "Operational: #{grouped.fetch("operational", []).size}, Degraded: #{grouped.fetch("degraded", []).size}, Down: #{grouped.fetch("down", []).size}"
  end

  def status_for_service(service_slug)
    response = api.get("/api/v1/services")
    return "Status unavailable (#{response[:code]})" unless response[:code] == 200

    service = (response[:body]["services"] || []).find { |item| item["slug"] == service_slug }
    return "Service '#{service_slug}' not found." unless service

    "#{service['name']}: #{service['status']}"
  end

  def active_incidents
    response = api.get("/api/v1/incidents")
    return "Incidents unavailable (#{response[:code]})" unless response[:code] == 200

    incidents = response[:body]["incidents"] || []
    return "No incidents." if incidents.empty?

    incidents.first(5).map do |incident|
      "##{incident['id']} #{incident['severity']} #{incident['state']}"
    end.join("\n")
  end

  def uptime_for(service_slug)
    return "Provide a service slug." if service_slug.to_s.empty?

    "Uptime endpoint for '#{service_slug}' will use SLA rollups in next increment."
  end

  def mutate_guard(event)
    return "Not authorized." unless mutation_allowed?(event)

    yield
  end

  def mutation_allowed?(event)
    user_id = event.user.id.to_s
    return true if allowlist.include?(user_id)

    return false if allowed_roles.empty? || event.server.nil?

    member = event.user.on(event.server)
    member_roles = member.roles.map { |role| role.id.to_s }
    (member_roles & allowed_roles).any?
  end

  def placeholder_mutation(action, payload = {})
    "#{action} accepted (placeholder). Payload: #{payload}"
  end
end

PulseDiscordBot.new.run if $PROGRAM_NAME == __FILE__
