class SlaRollupJob < ApplicationJob
  queue_as :maintenance

  WINDOWS = {
    "24h" => 24.hours,
    "7d" => 7.days,
    "30d" => 30.days
  }.freeze

  def perform
    Service.includes(:account).find_each do |service|
      WINDOWS.each do |window_key, span|
        calculate_rollup_for(service, window_key:, span:)
      end
    end
  end

  private

  def calculate_rollup_for(service, window_key:, span:)
    window_end = Time.current
    window_start = window_end - span

    results = service.check_results.where(created_at: window_start..window_end)
    total = results.count

    up_count = results.where(status: "up").count
    degraded_count = results.where(status: "degraded").count
    down_count = results.where(status: %w[down error]).count

    uptime_pct = percentage(up_count, total)
    degraded_pct = percentage(degraded_count, total)
    down_pct = percentage(down_count, total)

    SlaRollup.upsert(
      {
        account_id: service.account_id,
        service_id: service.id,
        window_key: window_key,
        window_start: window_start,
        window_end: window_end,
        uptime_pct: uptime_pct,
        degraded_pct: degraded_pct,
        down_pct: down_pct,
        total_samples: total,
        failed_samples: down_count,
        avg_latency_ms: results.where.not(duration_ms: nil).average(:duration_ms)&.to_i,
        p95_latency_ms: percentile_95(results.where.not(duration_ms: nil).pluck(:duration_ms)),
        updated_at: Time.current
      },
      unique_by: %i[service_id window_key]
    )
  end

  def percentage(count, total)
    return 0.0 if total.zero?

    ((count.to_f / total.to_f) * 100.0).round(4)
  end

  def percentile_95(values)
    return nil if values.empty?

    sorted = values.sort
    index = ((sorted.size - 1) * 0.95).round
    sorted[index]
  end
end
