module Monitoring
  module Strategies
    class Registry
      STRATEGIES = {
        "http_polling" => Monitoring::Strategies::HttpPollingStrategy,
        "synthetic_browser" => Monitoring::Strategies::SyntheticBrowserStrategy
      }.freeze

      def self.fetch(strategy)
        STRATEGIES.fetch(strategy.to_s) do
          raise KeyError, "No monitoring strategy registered for '#{strategy}'"
        end
      end
    end
  end
end
