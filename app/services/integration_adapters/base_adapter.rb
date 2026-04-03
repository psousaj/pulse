module IntegrationAdapters
  class BaseAdapter
    Result = Struct.new(:ok?, :duplicate?, :ingress, :health_event, :error_code, keyword_init: true)

    def initialize(endpoint:, payload:)
      @endpoint = endpoint
      @payload = payload.deep_stringify_keys
    end

    private

    attr_reader :endpoint, :payload

    def event_time_for(raw_value)
      return Time.current if raw_value.blank?

      Time.at(raw_value.to_i)
    rescue StandardError
      Time.current
    end
  end
end
