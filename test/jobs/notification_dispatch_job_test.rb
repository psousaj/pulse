require "test_helper"

class NotificationDispatchJobTest < ActiveJob::TestCase
  setup do
    clear_enqueued_jobs
    clear_performed_jobs
    ActionMailer::Base.deliveries.clear

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

  test "returns without dispatching when incident does not exist" do
    assert_no_difference("NotificationDelivery.count") do
      NotificationDispatchJob.perform_now(-1, "incident_opened")
    end
  end

  test "creates sent delivery using default email channel" do
    channel = NotificationChannel.create!(
      account: @account,
      kind: "email",
      name: "ops-email",
      enabled: true,
      is_default: true,
      config_encrypted: { to: [ "ops@example.com" ] }.to_json,
      throttle_minutes: 10
    )

    assert_difference("NotificationDelivery.count", 1) do
      assert_difference("ActionMailer::Base.deliveries.size", 1) do
        NotificationDispatchJob.perform_now(@incident.id, "incident_opened")
      end
    end

    delivery = NotificationDelivery.find_by!(notification_channel: channel)
    assert_equal "sent", delivery.status
    assert_not_nil delivery.delivered_at
    assert_equal [ "ops@example.com" ], Array(ActionMailer::Base.deliveries.last.to)
  end
end
