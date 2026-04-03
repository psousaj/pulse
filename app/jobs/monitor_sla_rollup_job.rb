class MonitorSlaRollupJob < ApplicationJob
  queue_as :maintenance

  WINDOWS = {
    "24h" => 24.hours,
    "7d" => 7.days,
    "30d" => 30.days
  }.freeze

  def perform
    PulseMonitor.includes(:account).find_each do |monitor|
      WINDOWS.each do |window_key, span|
        calculate_rollup_for(monitor, window_key:, span:)
      end
    end
  end

  private

  def calculate_rollup_for(monitor, window_key:, span:)
    window_end = Time.current
    window_start = window_end - span
    down_seconds = 0
    degraded_seconds = 0

    monitor.incidents.where("opened_at <= ?", window_end).find_each do |incident|
      durations = segment_durations_for(incident, window_start:, window_end:)
      down_seconds += durations[:down]
      degraded_seconds += durations[:degraded]
    end

    total_seconds = span.to_i
    uptime_pct = percentage(total_seconds - down_seconds, total_seconds)
    degraded_pct = percentage(degraded_seconds, total_seconds)
    down_pct = percentage(down_seconds, total_seconds)

    MonitorSlaRollup.upsert(
      {
        account_id: monitor.account_id,
        monitor_id: monitor.id,
        window_key: window_key,
        window_start: window_start,
        window_end: window_end,
        uptime_pct: uptime_pct,
        degraded_pct: degraded_pct,
        down_pct: down_pct,
        down_seconds: down_seconds,
        degraded_seconds: degraded_seconds,
        updated_at: Time.current
      },
      unique_by: [ :monitor_id, :window_key ]
    )
  end

  def segment_durations_for(incident, window_start:, window_end:)
    down_seconds = 0
    degraded_seconds = 0
    cursor = incident.opened_at
    current_severity = opened_severity_for(incident)

    relevant_events = incident.incident_events.where(event_type: %w[severity_changed resolved]).order(:created_at, :id)
    relevant_events.each do |event|
      event_time = event_timestamp(event)
      seconds = overlap_seconds(cursor, event_time, window_start, window_end)
      if current_severity == "down"
        down_seconds += seconds
      elsif current_severity == "degraded"
        degraded_seconds += seconds
      end

      cursor = event_time
      current_severity = event.to_state if event.event_type == "severity_changed"
      return { down: down_seconds, degraded: degraded_seconds } if event.event_type == "resolved"
    end

    end_time = incident.resolved_at || Time.current
    seconds = overlap_seconds(cursor, end_time, window_start, window_end)
    if current_severity == "down"
      down_seconds += seconds
    elsif current_severity == "degraded"
      degraded_seconds += seconds
    end

    { down: down_seconds, degraded: degraded_seconds }
  end

  def opened_severity_for(incident)
    opened_event = incident.incident_events.where(event_type: "opened").order(:id).first
    payload = opened_event&.payload_json
    payload.is_a?(Hash) ? payload["severity"].to_s.presence || incident.severity : incident.severity
  end

  def event_timestamp(event)
    payload = event.payload_json
    return event.created_at unless payload.is_a?(Hash)

    Time.zone.parse(payload["checked_at"].to_s)
  rescue StandardError
    event.created_at
  end

  def overlap_seconds(segment_start, segment_end, window_start, window_end)
    return 0 if segment_start.blank? || segment_end.blank?

    effective_start = [ segment_start, window_start ].max
    effective_end = [ segment_end, window_end ].min
    return 0 if effective_end <= effective_start

    (effective_end - effective_start).to_i
  end

  def percentage(value, total)
    return 0.0 if total.zero?

    ((value.to_f / total.to_f) * 100.0).round(4)
  end
end
