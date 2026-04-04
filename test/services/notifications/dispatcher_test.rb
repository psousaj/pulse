require "test_helper"

module Notifications
  class DispatcherTest < ActiveSupport::TestCase
    FakeResponse = Struct.new(:code, :body)

    class FakeHttpClient
      attr_accessor :use_ssl
      attr_reader :requests

      def initialize(response)
        @response = response
        @requests = []
      end

      def request(request)
        @requests << request
        @response
      end
    end

    setup do
      @account = create_account
      @service = create_service(account: @account)
      @service_check = create_service_check(service: @service)
      @incident = Incident.create!(
        account: @account,
        service: @service,
        service_check: @service_check,
        state: "open",
        severity: "down",
        title: "Service down",
        trigger_kind: "check_failure",
        opened_at: Time.current
      )
    end

    test "uses default channels when service does not define overrides" do
      channel = NotificationChannel.create!(
        account: @account,
        kind: "webhook",
        name: "default-webhook",
        enabled: true,
        is_default: true,
        config_encrypted: { url: "https://hooks.example/default" }.to_json,
        throttle_minutes: 10
      )

      fake_http = FakeHttpClient.new(FakeResponse.new("204", "ok"))

      with_temporary_class_method(Net::HTTP, :new, ->(_host, _port) { fake_http }) do
        Notifications::Dispatcher.new(incident: @incident, event_type: "incident_opened").call
      end

      delivery = NotificationDelivery.order(:id).last
      assert_equal channel.id, delivery.notification_channel_id
      assert_equal "sent", delivery.status
      assert_not_nil delivery.delivered_at
    end

    test "uses service specific channel over global defaults" do
      NotificationChannel.create!(
        account: @account,
        kind: "webhook",
        name: "global-webhook",
        enabled: true,
        is_default: true,
        config_encrypted: { url: "https://hooks.example/global" }.to_json,
        throttle_minutes: 10
      )

      service_channel = NotificationChannel.create!(
        account: @account,
        kind: "webhook",
        name: "service-webhook",
        enabled: true,
        is_default: false,
        config_encrypted: { url: "https://hooks.example/service" }.to_json,
        throttle_minutes: 10
      )

      ServiceNotification.create!(
        account: @account,
        service: @service,
        notification_channel: service_channel,
        enabled: true,
        override_json: {}
      )

      fake_http = FakeHttpClient.new(FakeResponse.new("204", "ok"))

      with_temporary_class_method(Net::HTTP, :new, ->(_host, _port) { fake_http }) do
        Notifications::Dispatcher.new(incident: @incident, event_type: "incident_opened").call
      end

      assert_equal [ service_channel.id ], NotificationDelivery.pluck(:notification_channel_id).uniq
    end

    test "marks delivery as failed when webhook returns error" do
      channel = NotificationChannel.create!(
        account: @account,
        kind: "webhook",
        name: "failing-webhook",
        enabled: true,
        is_default: true,
        config_encrypted: { url: "https://hooks.example/fail" }.to_json,
        throttle_minutes: 10
      )

      fake_http = FakeHttpClient.new(FakeResponse.new("500", "oops"))

      with_temporary_class_method(Net::HTTP, :new, ->(_host, _port) { fake_http }) do
        Notifications::Dispatcher.new(incident: @incident, event_type: "incident_opened").call
      end

      delivery = NotificationDelivery.find_by!(notification_channel: channel)
      assert_equal "failed", delivery.status
      assert_equal 1, delivery.attempt
      assert_equal 500, delivery.response_code
      assert_equal "oops", delivery.response_body
      assert_not_nil delivery.next_retry_at
    end

    test "delivers through email channel" do
      channel = NotificationChannel.create!(
        account: @account,
        kind: "email",
        name: "incident-email",
        enabled: true,
        is_default: true,
        config_encrypted: { to: [ "ops@example.com", "dev@example.com" ] }.to_json,
        throttle_minutes: 10
      )

      recipients_captured = nil
      mail_delivery = Object.new
      def mail_delivery.deliver_now
        true
      end

      with_temporary_class_method(NotificationMailer, :incident_alert, ->(_incident, recipients) {
        recipients_captured = recipients
        mail_delivery
      }) do
        Notifications::Dispatcher.new(incident: @incident, event_type: "incident_opened").call
      end

      delivery = NotificationDelivery.find_by!(notification_channel: channel)
      assert_equal "sent", delivery.status
      assert_not_nil delivery.delivered_at
      assert_equal [ "ops@example.com", "dev@example.com" ], recipients_captured
    end

    test "delivers discord channels through the webhook path" do
      channel = NotificationChannel.create!(
        account: @account,
        kind: "discord",
        name: "discord-webhook",
        enabled: true,
        is_default: true,
        config_encrypted: { url: "https://discord.example/webhook" }.to_json,
        throttle_minutes: 10
      )

      fake_http = FakeHttpClient.new(FakeResponse.new("204", "ok"))

      with_temporary_class_method(Net::HTTP, :new, ->(_host, _port) { fake_http }) do
        Notifications::Dispatcher.new(incident: @incident, event_type: "incident_opened").call
      end

      delivery = NotificationDelivery.find_by!(notification_channel: channel)
      assert_equal "sent", delivery.status
      assert_equal "application/json", fake_http.requests.first["Content-Type"]
      assert_match "[DOWN] Service down (open)", fake_http.requests.first.body
    end

    private

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
  end
end
