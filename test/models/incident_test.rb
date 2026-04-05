require "test_helper"

class IncidentTest < ActiveSupport::TestCase
  Actor = Struct.new(:subject, :username, :email, :id)

  test "acknowledge! stores an external actor reference" do
    account = create_account
    service = create_service(account: account)
    monitor = create_monitor(account: account, service: service)
    incident = create_monitor_incident(monitor: monitor)

    incident.acknowledge!(Actor.new("subject-123", "operator", "operator@example.com", "subject-123"))

    incident.reload
    assert_equal "acknowledged", incident.state
    assert_equal "subject-123", incident.acknowledged_by_ref
    assert_not_nil incident.acknowledged_at
  end

  test "resolve! stores an external actor reference and duration" do
    account = create_account
    service = create_service(account: account)
    monitor = create_monitor(account: account, service: service)
    incident = create_monitor_incident(monitor: monitor, opened_at: 3.minutes.ago)

    incident.resolve!(actor: Actor.new("subject-456", "operator", "operator@example.com", "subject-456"))

    incident.reload
    assert_equal "resolved", incident.state
    assert_equal "subject-456", incident.resolved_by_ref
    assert incident.duration_seconds >= 180
  end
end