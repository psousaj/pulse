namespace :pulse do
  desc "Issue JWT API tokens for a user and client"
  task :issue_api_token, %i[email client_name] => :environment do |_task, args|
    email = args[:email].to_s
    if email.empty?
      abort "Usage: bin/rails 'pulse:issue_api_token[user@example.com,discord-bot]'"
    end

    user = User.find_by!(email: email)
    client_name = args[:client_name].presence || "default-client"

    api_client = user.account.api_clients.find_or_create_by!(name: client_name)

    tokens = Api::TokenIssuer.new.issue!(
      user: user,
      api_client: api_client,
      scopes: %w[services:read incidents:read checks:write]
    )

    puts "API client: #{api_client.name} (uid=#{api_client.client_uid})"
    puts "ACCESS_TOKEN=#{tokens[:access_token]}"
    puts "REFRESH_TOKEN=#{tokens[:refresh_token]}"
    puts "ACCESS_EXPIRES_AT=#{tokens[:expires_at].iso8601}"
    puts "REFRESH_EXPIRES_AT=#{tokens[:refresh_expires_at].iso8601}"
  end
end
