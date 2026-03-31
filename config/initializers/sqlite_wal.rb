Rails.application.config.after_initialize do
  next unless defined?(ActiveRecord::Base)

  ActiveRecord::Base.connection_handler.connection_pool_list.each do |pool|
    pool.with_connection do |connection|
      next unless connection.adapter_name.downcase.include?("sqlite")

      connection.execute("PRAGMA journal_mode=WAL")
      connection.execute("PRAGMA synchronous=NORMAL")
      connection.execute("PRAGMA busy_timeout=5000")
      connection.execute("PRAGMA wal_autocheckpoint=1000")
    end
  rescue StandardError => error
    Rails.logger.warn("sqlite_wal_init_failed=#{error.class}: #{error.message}")
  end
end
