module ApplicationHelper
  def sidebar_nav_link_to(label, path, active: false)
    classes = [ "nav-link", "nav-link--sidebar" ]
    classes << "is-active" if active

    link_to label, path, class: classes.join(" ")
  end

  def dashboard_share(count, total)
    return 0.0 if total.to_i <= 0

    ((count.to_f / total) * 100).round(1)
  end

  def dashboard_status_tone(status)
    case status.to_s
    when "operational", "up", "enabled"
      "up"
    when "degraded"
      "degraded"
    when "down", "disabled"
      "down"
    else
      "neutral"
    end
  end

  def sparkline_points(values, width: 320, height: 88, padding: 10)
    series = Array(values).compact.map(&:to_f)
    series = [ 100.0 ] if series.empty?
    series = [ series.first, series.first ] if series.one?

    min = series.min
    max = series.max
    range = [ max - min, 1.0 ].max
    step = (width - padding * 2).to_f / (series.length - 1)

    series.each_with_index.map do |value, index|
      x = (padding + step * index).round(2)
      y = (height - padding - ((value - min) / range) * (height - padding * 2)).round(2)
      "#{x},#{y}"
    end.join(" ")
  end

  def sparkline_area_points(values, width: 320, height: 88, padding: 10)
    "#{padding},#{height - padding} #{sparkline_points(values, width:, height:, padding:)} #{width - padding},#{height - padding}"
  end
end
