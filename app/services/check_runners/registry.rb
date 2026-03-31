module CheckRunners
  class Registry
    RUNNERS = {
      "http" => CheckRunners::HttpRunner
    }.freeze

    def self.fetch(type_key)
      RUNNERS.fetch(type_key.to_s) do
        raise KeyError, "No runner registered for check type '#{type_key}'"
      end
    end
  end
end
