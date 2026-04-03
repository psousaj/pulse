require "ferrum"
require "fileutils"

module Monitoring
  module Strategies
    class SyntheticBrowserStrategy < BaseStrategy
      def call
        browser = build_browser
        page = browser.create_page
        started = monotonic_now
        checked_at = Time.current

        page.goto(config.fetch("url"), timeout: timeout_ms)
        page.network.wait_for_idle(timeout: timeout_ms) if page.respond_to?(:network)

        if config["wait_for_selector"].present?
          page.at_css(config["wait_for_selector"].to_s, wait: timeout_ms / 1000.0)
        end

        body = page.body.to_s
        status = evaluate_status(page, body)
        latency_ms = elapsed_ms_since(started)

        build_event(
          status: status,
          checked_at: checked_at,
          latency_ms: latency_ms,
          ttfb_ms: latency_ms,
          metadata: {
            url: config["url"],
            expected_text: config["expected_text"],
            wait_for_selector: config["wait_for_selector"]
          }
        )
      rescue StandardError => error
        build_event(
          status: "down",
          checked_at: Time.current,
          error_message: error.message,
          metadata: { reason: "synthetic_exception", error_class: error.class.name, url: config["url"] }
        )
      ensure
        browser&.quit
      end

      def self.capture_evidence(monitor)
        new(monitor).capture_screenshot
      end

      private

      def evaluate_status(page, body)
        return "down" if config["expected_text"].present? && !body.include?(config["expected_text"].to_s)
        return "down" if config["must_have_selector"].present? && page.at_css(config["must_have_selector"].to_s).blank?
        return "degraded" if degraded_threshold_ms.present? && config["render_time_ms"].to_i > degraded_threshold_ms

        "up"
      end

      def capture_screenshot
        browser = build_browser
        page = browser.create_page
        page.goto(config.fetch("url"), timeout: timeout_ms)
        page.network.wait_for_idle(timeout: timeout_ms) if page.respond_to?(:network)

        FileUtils.mkdir_p(screenshot_dir)
        path = File.join(screenshot_dir, "monitor-#{monitor.id}-#{Time.current.to_i}.png")
        page.screenshot(path: path, full: true)
        path
      rescue StandardError
        nil
      ensure
        browser&.quit
      end

      def build_browser
        browser_url = ENV["FERRUM_BROWSER_URL"].to_s.presence
        options = { timeout: timeout_ms / 1000.0 }
        options[:browser_url] = browser_url if browser_url.present?
        Ferrum::Browser.new(**options)
      end

      def timeout_ms
        config.fetch("timeout_ms", 5000).to_i
      end

      def screenshot_dir
        Rails.root.join("storage", "monitor_screenshots")
      end
    end
  end
end
