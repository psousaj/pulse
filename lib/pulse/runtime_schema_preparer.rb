module Pulse
  class RuntimeSchemaPreparer
    SCHEMAS = {
      queue: {
        file: "db/queue_schema.rb",
        tables: %w[solid_queue_jobs solid_queue_recurring_tasks]
      },
      cache: {
        file: "db/cache_schema.rb",
        tables: %w[solid_cache_entries]
      },
      cable: {
        file: "db/cable_schema.rb",
        tables: %w[solid_cable_messages]
      }
    }.freeze

    def self.prepare!(connection: ActiveRecord::Base.connection, env_name: Rails.env)
      new(connection:, env_name:).prepare!
    end

    def initialize(connection:, env_name:)
      @connection = connection
      @env_name = env_name
    end

    def prepare!
      return false unless single_sqlite_database_environment?

      prepared_any = false

      SCHEMAS.each_value do |schema|
        next if schema[:tables].all? { |table| connection.data_source_exists?(table) }

        load Rails.root.join(schema[:file]).to_s
        prepared_any = true
      end

      connection.schema_cache.clear!
      prepared_any
    end

    private

    attr_reader :connection, :env_name

    def single_sqlite_database_environment?
      return false unless connection.adapter_name.casecmp("sqlite").zero?

      ActiveRecord::Base.configurations.configs_for(env_name:, name: "queue").blank?
    end
  end
end
