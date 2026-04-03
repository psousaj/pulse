module Monitoring
  class IncidentEvidenceCapturer
    def self.call(monitor:, health_event:)
      return nil unless monitor.strategy == "synthetic_browser"

      strategy = Monitoring::Strategies::Registry.fetch(monitor.strategy)
      strategy.capture_evidence(monitor)
    rescue StandardError
      nil
    end
  end
end
