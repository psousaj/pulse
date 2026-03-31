class CheckExecutionJob < ApplicationJob
  queue_as :checks_regular

  def perform(service_check_id, scheduled_at: nil)
    service_check = ServiceCheck.includes(:account, :service, :health_check_type).find_by(id: service_check_id)
    return if service_check.blank? || !service_check.enabled?

    Monitoring::CheckExecutionService.new(service_check:, scheduled_at:).call
  end
end
