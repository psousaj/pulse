require "json"
require "net/http"
require "uri"

module Notifications
  class Dispatcher
    def initialize(incident:, event_type:)
      @incident = incident
      @event_type = event_type
    end

    def call
      channels.each do |channel|
        delivery = NotificationDelivery.create!(
          account: incident.account,
          incident: incident,
          notification_channel: channel,
          event_type: event_type,
          status: "queued"
        )

        deliver(channel, delivery)
      end
    end

    private

    attr_reader :incident, :event_type

    def channels
      service = incident.notification_service
      return incident.account.notification_channels.defaults.where(enabled: true) if service.blank?

      service_channel_ids = service.service_notifications.where(enabled: true).pluck(:notification_channel_id)
      service_channels = NotificationChannel.where(id: service_channel_ids, enabled: true)

      return service_channels if service_channels.any?

      incident.account.notification_channels.defaults.where(enabled: true)
    end

    def deliver(channel, delivery)
      case channel.kind
      when "discord"
        deliver_via_webhook(channel, delivery)
      when "webhook"
        deliver_via_webhook(channel, delivery)
      when "email"
        deliver_via_email(channel, delivery)
      else
        fail_delivery(delivery, "unsupported_channel_kind")
      end
    rescue StandardError => error
      fail_delivery(delivery, error.message)
    end

    def deliver_via_webhook(channel, delivery)
      config = parsed_config(channel)
      url = config["url"].to_s
      raise "missing_webhook_url" if url.empty?

      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = {
        content: "[#{incident.severity.upcase}] #{incident.title} (#{incident.state})"
      }.to_json

      response = http.request(request)
      if response.code.to_i.between?(200, 299)
        delivery.update!(status: "sent", delivered_at: Time.current, response_code: response.code.to_i, response_body: response.body.to_s)
      else
        fail_delivery(delivery, "webhook_response_#{response.code}", response: response)
      end
    end

    def deliver_via_email(channel, delivery)
      config = parsed_config(channel)
      recipients = Array(config["to"]).flat_map { |item| item.to_s.split(",") }.map(&:strip).reject(&:empty?)
      raise "missing_email_recipients" if recipients.empty?

      NotificationMailer.incident_alert(incident, recipients).deliver_now
      delivery.update!(status: "sent", delivered_at: Time.current)
    end

    def parsed_config(channel)
      JSON.parse(channel.config_encrypted.to_s.presence || "{}")
    rescue JSON::ParserError
      {}
    end

    def fail_delivery(delivery, message, response: nil)
      delivery.update!(
        status: "failed",
        attempt: delivery.attempt + 1,
        error_message: message,
        response_code: response&.code&.to_i,
        response_body: response&.body,
        next_retry_at: Time.current + retry_backoff(delivery.attempt + 1)
      )
    end

    def retry_backoff(attempt)
      [ attempt**2, 30 ].min.minutes
    end
  end
end
