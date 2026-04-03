class AddEventDrivenMonitoringCore < ActiveRecord::Migration[8.1]
  def change
    create_table :monitors do |t|
      t.references :account, null: false, foreign_key: true
      t.references :service, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.string :strategy, null: false, default: "event_only"
      t.json :config_json
      t.integer :interval_seconds
      t.boolean :enabled, null: false, default: true
      t.string :current_status, null: false, default: "up"
      t.datetime :next_run_at
      t.datetime :last_run_at
      t.string :lease_token
      t.datetime :lease_expires_at
      t.timestamps
    end
    add_index :monitors, [ :account_id, :slug ], unique: true
    add_index :monitors, [ :enabled, :next_run_at ]
    add_index :monitors, :lease_expires_at

    create_table :integration_endpoints do |t|
      t.references :account, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :name, null: false
      t.string :secret_digest, null: false
      t.boolean :enabled, null: false, default: true
      t.json :config_json
      t.timestamps
    end
    add_index :integration_endpoints, [ :account_id, :provider, :name ], unique: true
    add_index :integration_endpoints, :secret_digest, unique: true

    create_table :monitor_source_bindings do |t|
      t.references :account, null: false, foreign_key: true
      t.references :monitor, null: false, foreign_key: true
      t.references :integration_endpoint, foreign_key: true
      t.string :kind, null: false
      t.string :provider
      t.string :role, null: false, default: "corroborative"
      t.string :external_ref
      t.string :token_digest
      t.boolean :enabled, null: false, default: true
      t.json :config_json
      t.timestamps
    end
    add_index :monitor_source_bindings,
      [ :monitor_id, :kind, :provider, :external_ref ],
      unique: true,
      name: "idx_monitor_source_bindings_uniqueness"
    add_index :monitor_source_bindings, :token_digest, unique: true

    create_table :health_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :service, foreign_key: true
      t.references :monitor, null: false, foreign_key: true
      t.references :monitor_source_binding, foreign_key: true
      t.string :source, null: false
      t.string :status, null: false
      t.boolean :authoritative, null: false, default: true
      t.integer :latency_ms
      t.integer :ttfb_ms
      t.integer :tls_ms
      t.integer :dns_ms
      t.string :screenshot_path
      t.text :error_message
      t.json :metadata_json
      t.datetime :checked_at, null: false
      t.timestamps
    end
    add_index :health_events, [ :monitor_id, :checked_at ]
    add_index :health_events, [ :monitor_id, :authoritative, :checked_at ], name: "idx_health_events_authoritative_order"

    create_table :integration_event_ingresses do |t|
      t.references :account, null: false, foreign_key: true
      t.references :integration_endpoint, null: false, foreign_key: true
      t.references :monitor_source_binding, foreign_key: true
      t.references :health_event, foreign_key: true
      t.string :provider, null: false
      t.string :idempotency_key, null: false
      t.string :status, null: false, default: "received"
      t.string :external_ref
      t.string :error_code
      t.json :payload_json
      t.datetime :received_at, null: false
      t.datetime :processed_at
      t.timestamps
    end
    add_index :integration_event_ingresses,
      [ :integration_endpoint_id, :idempotency_key ],
      unique: true,
      name: "idx_integration_ingresses_dedup"

    create_table :monitor_sla_rollups do |t|
      t.references :account, null: false, foreign_key: true
      t.references :monitor, null: false, foreign_key: true
      t.string :window_key, null: false
      t.datetime :window_start, null: false
      t.datetime :window_end, null: false
      t.decimal :uptime_pct, precision: 7, scale: 4, null: false, default: 0.0
      t.decimal :degraded_pct, precision: 7, scale: 4, null: false, default: 0.0
      t.decimal :down_pct, precision: 7, scale: 4, null: false, default: 0.0
      t.integer :down_seconds, null: false, default: 0
      t.integer :degraded_seconds, null: false, default: 0
      t.datetime :updated_at
    end
    add_index :monitor_sla_rollups, [ :monitor_id, :window_key ], unique: true

    add_reference :incidents, :monitor, foreign_key: { to_table: :monitors }
    add_reference :incidents, :first_health_event, foreign_key: { to_table: :health_events }
    add_reference :incidents, :last_health_event, foreign_key: { to_table: :health_events }
    add_column :incidents, :root_cause, :text
    add_column :incidents, :duration_seconds, :integer
    add_index :incidents, [ :monitor_id, :state ]

    add_reference :heartbeat_tokens, :monitor, foreign_key: { to_table: :monitors }

    change_column_null :incidents, :service_id, true
  end
end
