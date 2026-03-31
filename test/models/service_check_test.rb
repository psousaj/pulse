require "test_helper"

class ServiceCheckTest < ActiveSupport::TestCase
  setup do
    @account = create_account
    @service = create_service(account: @account)
  end

  test "rejects unsupported interval" do
    check = create_service_check(service: @service)
    check.interval_seconds = 10

    assert_not check.valid?
    assert_includes check.errors[:interval_seconds], "is not included in the list"
  end

  test "acquires and releases lease" do
    check = create_service_check(service: @service)

    assert check.acquire_lease!
    check.reload
    assert check.lease_token.present?
    assert check.lease_expires_at.present?

    assert_not check.acquire_lease!

    check.release_lease!
    check.reload
    assert_nil check.lease_token
    assert_nil check.lease_expires_at
  end

  test "schedules next run from timestamp" do
    check = create_service_check(service: @service)
    from = Time.current.change(usec: 0)

    check.schedule_next_run!(from: from)
    check.reload

    assert_equal from, check.last_run_at
    assert_equal from + check.interval_seconds, check.next_run_at
  end
end
