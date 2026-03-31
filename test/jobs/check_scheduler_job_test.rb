require "test_helper"

class CheckSchedulerJobTest < ActiveJob::TestCase
  setup do
    clear_enqueued_jobs
    clear_performed_jobs

    @account = create_account
    @service = create_service(account: @account)
  end

  test "enqueues due checks with queue based on interval" do
    fast_check = create_service_check(service: @service, name: "Fast check")
    fast_check.update!(interval_seconds: 30, next_run_at: 1.minute.ago)

    regular_check = create_service_check(service: @service, name: "Regular check")
    regular_check.update!(interval_seconds: 60, next_run_at: 1.minute.ago)

    assert_difference -> { enqueued_jobs_for(CheckExecutionJob).size }, 2 do
      CheckSchedulerJob.perform_now
    end

    queues = enqueued_jobs_for(CheckExecutionJob).map { |job| job[:queue] }
    assert_includes queues, "checks_fast"
    assert_includes queues, "checks_regular"
  end

  test "does not enqueue when lease cannot be acquired" do
    leased_check = create_service_check(service: @service, name: "Leased check")
    leased_check.update!(next_run_at: 1.minute.ago, lease_token: "busy", lease_expires_at: 10.minutes.from_now)

    assert_no_difference -> { enqueued_jobs_for(CheckExecutionJob).size } do
      CheckSchedulerJob.perform_now
    end
  end

  private

  def enqueued_jobs_for(job_class)
    enqueued_jobs.select { |job| job[:job] == job_class }
  end
end