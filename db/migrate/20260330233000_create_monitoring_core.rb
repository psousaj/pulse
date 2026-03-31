class CreateMonitoringCore < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :timezone, null: false, default: "UTC"
      t.integer :default_alert_interval_minutes, null: false, default: 10
      t.timestamps
    end
    add_index :accounts, :slug, unique: true

    create_table :users do |t|
      t.references :account, null: false, foreign_key: true
      t.string :email, null: false
      t.string :name, null: false
      t.string :role, null: false, default: "owner"
      t.string :github_uid
      t.boolean :active, null: false, default: true
      t.datetime :last_login_at
      t.timestamps
    end
    add_index :users, [ :account_id, :email ], unique: true
    add_index :users, [ :account_id, :github_uid ], unique: true

    create_table :services do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :visibility, null: false, default: "private"
      t.string :current_status, null: false, default: "operational"
      t.boolean :paused, null: false, default: false
      t.datetime :maintenance_starts_at
      t.datetime :maintenance_ends_at
      t.timestamps
    end
    add_index :services, [ :account_id, :slug ], unique: true

    create_table :health_check_types do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :runner_class, null: false
      t.boolean :enabled, null: false, default: true
      t.integer :config_schema_version, null: false, default: 1
      t.timestamps
    end
    add_index :health_check_types, :key, unique: true

    create_table :service_checks do |t|
      t.references :account, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.references :health_check_type, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :enabled, null: false, default: true
      t.boolean :critical, null: false, default: true
      t.integer :interval_seconds, null: false, default: 60
      t.integer :timeout_ms, null: false, default: 5000
      t.integer :max_latency_ms
      t.json :config_json
      t.datetime :next_run_at
      t.datetime :last_run_at
      t.integer :consecutive_failures, null: false, default: 0
      t.integer :consecutive_successes, null: false, default: 0
      t.string :lease_token
      t.datetime :lease_expires_at
      t.timestamps
    end
    add_index :service_checks, [ :service_id, :name ], unique: true
    add_index :service_checks, [ :enabled, :next_run_at ]
    add_index :service_checks, [ :lease_expires_at ]

    create_table :check_results do |t|
      t.references :account, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.references :service_check, null: false, foreign_key: true
      t.datetime :scheduled_at
      t.datetime :started_at, null: false
      t.datetime :finished_at, null: false
      t.integer :duration_ms
      t.string :status, null: false, default: "up"
      t.integer :http_status_code
      t.text :body_excerpt
      t.text :json_path_result
      t.boolean :latency_breached, null: false, default: false
      t.boolean :timed_out, null: false, default: false
      t.string :error_class
      t.text :error_message
      t.json :metadata_json
      t.timestamps
    end
    add_index :check_results, [ :service_check_id, :created_at ]
    add_index :check_results, [ :service_id, :created_at ]

    create_table :incidents do |t|
      t.references :account, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.references :service_check, foreign_key: true
      t.string :state, null: false, default: "open"
      t.string :severity, null: false, default: "down"
      t.string :title, null: false
      t.string :trigger_kind, null: false, default: "check_failure"
      t.datetime :opened_at, null: false
      t.datetime :acknowledged_at
      t.datetime :resolved_at
      t.references :acknowledged_by_user, foreign_key: { to_table: :users }
      t.references :resolved_by_user, foreign_key: { to_table: :users }
      t.references :first_check_result, foreign_key: { to_table: :check_results }
      t.references :last_check_result, foreign_key: { to_table: :check_results }
      t.timestamps
    end
    add_index :incidents, [ :service_id, :state ]

    create_table :incident_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :incident, null: false, foreign_key: true
      t.string :event_type, null: false
      t.string :from_state
      t.string :to_state
      t.string :actor_type, null: false, default: "system"
      t.string :actor_ref
      t.json :payload_json
      t.timestamps
    end

    create_table :notification_channels do |t|
      t.references :account, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :name, null: false
      t.boolean :enabled, null: false, default: true
      t.boolean :is_default, null: false, default: false
      t.text :config_encrypted
      t.integer :throttle_minutes, null: false, default: 10
      t.timestamps
    end
    add_index :notification_channels, [ :account_id, :name ], unique: true

    create_table :service_notifications do |t|
      t.references :account, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.references :notification_channel, null: false, foreign_key: true
      t.boolean :enabled, null: false, default: true
      t.json :override_json
      t.timestamps
    end
    add_index :service_notifications, [ :service_id, :notification_channel_id ], unique: true

    create_table :notification_deliveries do |t|
      t.references :account, null: false, foreign_key: true
      t.references :incident, null: false, foreign_key: true
      t.references :notification_channel, null: false, foreign_key: true
      t.string :event_type, null: false
      t.string :status, null: false, default: "queued"
      t.integer :attempt, null: false, default: 0
      t.datetime :next_retry_at
      t.integer :response_code
      t.text :response_body
      t.text :error_message
      t.datetime :delivered_at
      t.timestamps
    end
    add_index :notification_deliveries, [ :status, :next_retry_at ]

    create_table :heartbeat_tokens do |t|
      t.references :account, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.integer :expected_interval_seconds, null: false, default: 60
      t.integer :grace_seconds, null: false, default: 30
      t.datetime :last_heartbeat_at
      t.datetime :next_expected_at
      t.boolean :enabled, null: false, default: true
      t.text :description
      t.timestamps
    end
    add_index :heartbeat_tokens, :token_digest, unique: true
    add_index :heartbeat_tokens, [ :enabled, :next_expected_at ]

    create_table :api_clients do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :client_uid, null: false
      t.string :client_secret_digest, null: false
      t.json :scopes_json
      t.boolean :active, null: false, default: true
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :api_clients, :client_uid, unique: true

    create_table :api_access_tokens do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :api_client, null: false, foreign_key: true
      t.string :jti, null: false
      t.string :token_digest, null: false
      t.json :scopes_json
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :api_access_tokens, :jti, unique: true
    add_index :api_access_tokens, :token_digest, unique: true

    create_table :api_refresh_tokens do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :api_client, null: false, foreign_key: true
      t.string :jti, null: false
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :api_refresh_tokens, :jti, unique: true
    add_index :api_refresh_tokens, :token_digest, unique: true

    create_table :sla_rollups do |t|
      t.references :account, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.string :window_key, null: false
      t.datetime :window_start, null: false
      t.datetime :window_end, null: false
      t.decimal :uptime_pct, precision: 7, scale: 4, null: false, default: 0.0
      t.decimal :degraded_pct, precision: 7, scale: 4, null: false, default: 0.0
      t.decimal :down_pct, precision: 7, scale: 4, null: false, default: 0.0
      t.integer :total_samples, null: false, default: 0
      t.integer :failed_samples, null: false, default: 0
      t.integer :avg_latency_ms
      t.integer :p95_latency_ms
      t.datetime :updated_at
    end
    add_index :sla_rollups, [ :service_id, :window_key ], unique: true

    create_table :settings do |t|
      t.references :account, foreign_key: true
      t.string :namespace, null: false
      t.string :key, null: false
      t.json :value_json
      t.timestamps
    end
    add_index :settings, [ :account_id, :namespace, :key ], unique: true

    create_table :audit_logs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :source, null: false
      t.string :action, null: false
      t.string :target_type, null: false
      t.bigint :target_id, null: false
      t.json :payload_json
      t.timestamps
    end
    add_index :audit_logs, [ :target_type, :target_id ]
  end
end
