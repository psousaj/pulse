namespace :pulse do
  desc "Audit remaining legacy monitoring footprint before cutting over fully to monitors"
  task audit_legacy_monitoring: :environment do
    puts "Legacy monitoring cutover audit"
    puts

    services = Service.includes(:account, :service_checks, :monitors).order(:account_id, :name)
    candidates = services.select { |service| service.service_checks.size.positive? || service.monitors.empty? }

    if candidates.empty?
      puts "No services are missing monitor coverage and no legacy service checks remain attached."
    else
      candidates.each do |service|
        puts "#{service.account.slug}/#{service.slug}"
        puts "  legacy_checks=#{service.service_checks.size} monitors=#{service.monitors.size} status=#{service.current_status}"

        service.service_checks.order(:name).each do |check|
          puts "  check #{check.name} type=#{check.health_check_type&.key || 'unknown'} enabled=#{check.enabled}"
        end

        service.monitors.order(:name).each do |monitor|
          puts "  monitor #{monitor.name} strategy=#{monitor.strategy} enabled=#{monitor.enabled}"
        end

        puts
      end
    end

    puts "Legacy tables"
    puts "  ServiceCheck rows: #{ServiceCheck.count}"
    puts "  CheckResult rows: #{CheckResult.count}"
    puts "  Incident rows linked to service_check: #{Incident.where.not(service_check_id: nil).count}"
    puts "  Incident rows linked to monitor: #{Incident.where.not(monitor_id: nil).count}"
  end
end
