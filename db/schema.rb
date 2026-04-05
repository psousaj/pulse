# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_04_120000) do
  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "default_alert_interval_minutes", default: 10, null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.string "timezone", default: "UTC", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_accounts_on_slug", unique: true
  end

  create_table "audit_logs", force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "action", null: false
    t.string "actor_ref"
    t.datetime "created_at", null: false
    t.json "payload_json"
    t.string "source", null: false
    t.bigint "target_id", null: false
    t.string "target_type", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_audit_logs_on_account_id"
    t.index ["target_type", "target_id"], name: "index_audit_logs_on_target_type_and_target_id"
  end

  create_table "check_results", force: :cascade do |t|
    t.integer "account_id", null: false
    t.text "body_excerpt"
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.string "error_class"
    t.text "error_message"
    t.datetime "finished_at", null: false
    t.integer "http_status_code"
    t.text "json_path_result"
    t.boolean "latency_breached", default: false, null: false
    t.json "metadata_json"
    t.datetime "scheduled_at"
    t.integer "service_check_id", null: false
    t.integer "service_id", null: false
    t.datetime "started_at", null: false
    t.string "status", default: "up", null: false
    t.boolean "timed_out", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_check_results_on_account_id"
    t.index ["service_check_id", "created_at"], name: "index_check_results_on_service_check_id_and_created_at"
    t.index ["service_check_id"], name: "index_check_results_on_service_check_id"
    t.index ["service_id", "created_at"], name: "index_check_results_on_service_id_and_created_at"
    t.index ["service_id"], name: "index_check_results_on_service_id"
  end

  create_table "health_check_types", force: :cascade do |t|
    t.integer "config_schema_version", default: 1, null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.string "key", null: false
    t.string "name", null: false
    t.string "runner_class", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_health_check_types_on_key", unique: true
  end

  create_table "health_events", force: :cascade do |t|
    t.integer "account_id", null: false
    t.boolean "authoritative", default: true, null: false
    t.datetime "checked_at", null: false
    t.datetime "created_at", null: false
    t.integer "dns_ms"
    t.text "error_message"
    t.integer "latency_ms"
    t.json "metadata_json"
    t.integer "monitor_id", null: false
    t.integer "monitor_source_binding_id"
    t.string "screenshot_path"
    t.integer "service_id"
    t.string "source", null: false
    t.string "status", null: false
    t.integer "tls_ms"
    t.integer "ttfb_ms"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_health_events_on_account_id"
    t.index ["monitor_id", "authoritative", "checked_at"], name: "idx_health_events_authoritative_order"
    t.index ["monitor_id", "checked_at"], name: "index_health_events_on_monitor_id_and_checked_at"
    t.index ["monitor_id"], name: "index_health_events_on_monitor_id"
    t.index ["monitor_source_binding_id"], name: "index_health_events_on_monitor_source_binding_id"
    t.index ["service_id"], name: "index_health_events_on_service_id"
  end

  create_table "heartbeat_tokens", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "enabled", default: true, null: false
    t.integer "expected_interval_seconds", default: 60, null: false
    t.integer "grace_seconds", default: 30, null: false
    t.datetime "last_heartbeat_at"
    t.integer "monitor_id"
    t.datetime "next_expected_at"
    t.integer "service_id", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_heartbeat_tokens_on_account_id"
    t.index ["enabled", "next_expected_at"], name: "index_heartbeat_tokens_on_enabled_and_next_expected_at"
    t.index ["monitor_id"], name: "index_heartbeat_tokens_on_monitor_id"
    t.index ["service_id"], name: "index_heartbeat_tokens_on_service_id"
    t.index ["token_digest"], name: "index_heartbeat_tokens_on_token_digest", unique: true
  end

  create_table "incident_events", force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "actor_ref"
    t.string "actor_type", default: "system", null: false
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.string "from_state"
    t.integer "incident_id", null: false
    t.json "payload_json"
    t.string "to_state"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_incident_events_on_account_id"
    t.index ["incident_id"], name: "index_incident_events_on_incident_id"
  end

  create_table "incidents", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "acknowledged_at"
    t.string "acknowledged_by_ref"
    t.datetime "created_at", null: false
    t.integer "duration_seconds"
    t.integer "first_check_result_id"
    t.integer "first_health_event_id"
    t.integer "last_check_result_id"
    t.integer "last_health_event_id"
    t.integer "monitor_id"
    t.datetime "opened_at", null: false
    t.datetime "resolved_at"
    t.string "resolved_by_ref"
    t.text "root_cause"
    t.integer "service_check_id"
    t.integer "service_id"
    t.string "severity", default: "down", null: false
    t.string "state", default: "open", null: false
    t.string "title", null: false
    t.string "trigger_kind", default: "check_failure", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_incidents_on_account_id"
    t.index ["first_check_result_id"], name: "index_incidents_on_first_check_result_id"
    t.index ["first_health_event_id"], name: "index_incidents_on_first_health_event_id"
    t.index ["last_check_result_id"], name: "index_incidents_on_last_check_result_id"
    t.index ["last_health_event_id"], name: "index_incidents_on_last_health_event_id"
    t.index ["monitor_id", "state"], name: "index_incidents_on_monitor_id_and_state"
    t.index ["monitor_id"], name: "index_incidents_on_monitor_id"
    t.index ["service_check_id"], name: "index_incidents_on_service_check_id"
    t.index ["service_id", "state"], name: "index_incidents_on_service_id_and_state"
    t.index ["service_id"], name: "index_incidents_on_service_id"
  end

  create_table "integration_endpoints", force: :cascade do |t|
    t.integer "account_id", null: false
    t.json "config_json"
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.string "name", null: false
    t.string "provider", null: false
    t.string "secret_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "provider", "name"], name: "idx_on_account_id_provider_name_12909240b9", unique: true
    t.index ["account_id"], name: "index_integration_endpoints_on_account_id"
    t.index ["secret_digest"], name: "index_integration_endpoints_on_secret_digest", unique: true
  end

  create_table "integration_event_ingresses", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.string "error_code"
    t.string "external_ref"
    t.integer "health_event_id"
    t.string "idempotency_key", null: false
    t.integer "integration_endpoint_id", null: false
    t.integer "monitor_source_binding_id"
    t.json "payload_json"
    t.datetime "processed_at"
    t.string "provider", null: false
    t.datetime "received_at", null: false
    t.string "status", default: "received", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_integration_event_ingresses_on_account_id"
    t.index ["health_event_id"], name: "index_integration_event_ingresses_on_health_event_id"
    t.index ["integration_endpoint_id", "idempotency_key"], name: "idx_integration_ingresses_dedup", unique: true
    t.index ["integration_endpoint_id"], name: "index_integration_event_ingresses_on_integration_endpoint_id"
    t.index ["monitor_source_binding_id"], name: "index_integration_event_ingresses_on_monitor_source_binding_id"
  end

  create_table "monitor_sla_rollups", force: :cascade do |t|
    t.integer "account_id", null: false
    t.decimal "degraded_pct", precision: 7, scale: 4, default: "0.0", null: false
    t.integer "degraded_seconds", default: 0, null: false
    t.decimal "down_pct", precision: 7, scale: 4, default: "0.0", null: false
    t.integer "down_seconds", default: 0, null: false
    t.integer "monitor_id", null: false
    t.datetime "updated_at"
    t.decimal "uptime_pct", precision: 7, scale: 4, default: "0.0", null: false
    t.datetime "window_end", null: false
    t.string "window_key", null: false
    t.datetime "window_start", null: false
    t.index ["account_id"], name: "index_monitor_sla_rollups_on_account_id"
    t.index ["monitor_id", "window_key"], name: "index_monitor_sla_rollups_on_monitor_id_and_window_key", unique: true
    t.index ["monitor_id"], name: "index_monitor_sla_rollups_on_monitor_id"
  end

  create_table "monitor_source_bindings", force: :cascade do |t|
    t.integer "account_id", null: false
    t.json "config_json"
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.string "external_ref"
    t.integer "integration_endpoint_id"
    t.string "kind", null: false
    t.integer "monitor_id", null: false
    t.string "provider"
    t.string "role", default: "corroborative", null: false
    t.string "token_digest"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_monitor_source_bindings_on_account_id"
    t.index ["integration_endpoint_id"], name: "index_monitor_source_bindings_on_integration_endpoint_id"
    t.index ["monitor_id", "kind", "provider", "external_ref"], name: "idx_monitor_source_bindings_uniqueness", unique: true
    t.index ["monitor_id"], name: "index_monitor_source_bindings_on_monitor_id"
    t.index ["token_digest"], name: "index_monitor_source_bindings_on_token_digest", unique: true
  end

  create_table "monitors", force: :cascade do |t|
    t.integer "account_id", null: false
    t.json "config_json"
    t.datetime "created_at", null: false
    t.string "current_status", default: "up", null: false
    t.boolean "enabled", default: true, null: false
    t.integer "interval_seconds"
    t.datetime "last_run_at"
    t.datetime "lease_expires_at"
    t.string "lease_token"
    t.string "name", null: false
    t.datetime "next_run_at"
    t.integer "service_id"
    t.string "slug", null: false
    t.string "strategy", default: "event_only", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "slug"], name: "index_monitors_on_account_id_and_slug", unique: true
    t.index ["account_id"], name: "index_monitors_on_account_id"
    t.index ["enabled", "next_run_at"], name: "index_monitors_on_enabled_and_next_run_at"
    t.index ["lease_expires_at"], name: "index_monitors_on_lease_expires_at"
    t.index ["service_id"], name: "index_monitors_on_service_id"
  end

  create_table "notification_channels", force: :cascade do |t|
    t.integer "account_id", null: false
    t.text "config_encrypted"
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.boolean "is_default", default: false, null: false
    t.string "kind", null: false
    t.string "name", null: false
    t.integer "throttle_minutes", default: 10, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "name"], name: "index_notification_channels_on_account_id_and_name", unique: true
    t.index ["account_id"], name: "index_notification_channels_on_account_id"
  end

  create_table "notification_deliveries", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "attempt", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.text "error_message"
    t.string "event_type", null: false
    t.integer "incident_id", null: false
    t.datetime "next_retry_at"
    t.integer "notification_channel_id", null: false
    t.text "response_body"
    t.integer "response_code"
    t.string "status", default: "queued", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_notification_deliveries_on_account_id"
    t.index ["incident_id"], name: "index_notification_deliveries_on_incident_id"
    t.index ["notification_channel_id"], name: "index_notification_deliveries_on_notification_channel_id"
    t.index ["status", "next_retry_at"], name: "index_notification_deliveries_on_status_and_next_retry_at"
  end

  create_table "service_checks", force: :cascade do |t|
    t.integer "account_id", null: false
    t.json "config_json"
    t.integer "consecutive_failures", default: 0, null: false
    t.integer "consecutive_successes", default: 0, null: false
    t.datetime "created_at", null: false
    t.boolean "critical", default: true, null: false
    t.boolean "enabled", default: true, null: false
    t.integer "health_check_type_id", null: false
    t.integer "interval_seconds", default: 60, null: false
    t.datetime "last_run_at"
    t.datetime "lease_expires_at"
    t.string "lease_token"
    t.integer "max_latency_ms"
    t.string "name", null: false
    t.datetime "next_run_at"
    t.integer "service_id", null: false
    t.integer "timeout_ms", default: 5000, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_service_checks_on_account_id"
    t.index ["enabled", "next_run_at"], name: "index_service_checks_on_enabled_and_next_run_at"
    t.index ["health_check_type_id"], name: "index_service_checks_on_health_check_type_id"
    t.index ["lease_expires_at"], name: "index_service_checks_on_lease_expires_at"
    t.index ["service_id", "name"], name: "index_service_checks_on_service_id_and_name", unique: true
    t.index ["service_id"], name: "index_service_checks_on_service_id"
  end

  create_table "service_notifications", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.integer "notification_channel_id", null: false
    t.json "override_json"
    t.integer "service_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_service_notifications_on_account_id"
    t.index ["notification_channel_id"], name: "index_service_notifications_on_notification_channel_id"
    t.index ["service_id", "notification_channel_id"], name: "idx_on_service_id_notification_channel_id_43ff187ab6", unique: true
    t.index ["service_id"], name: "index_service_notifications_on_service_id"
  end

  create_table "services", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.string "current_status", default: "operational", null: false
    t.text "description"
    t.datetime "maintenance_ends_at"
    t.datetime "maintenance_starts_at"
    t.string "name", null: false
    t.boolean "paused", default: false, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.string "visibility", default: "private", null: false
    t.index ["account_id", "slug"], name: "index_services_on_account_id_and_slug", unique: true
    t.index ["account_id"], name: "index_services_on_account_id"
  end

  create_table "settings", force: :cascade do |t|
    t.integer "account_id"
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "namespace", null: false
    t.datetime "updated_at", null: false
    t.json "value_json"
    t.index ["account_id", "namespace", "key"], name: "index_settings_on_account_id_and_namespace_and_key", unique: true
    t.index ["account_id"], name: "index_settings_on_account_id"
  end

  create_table "sla_rollups", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "avg_latency_ms"
    t.decimal "degraded_pct", precision: 7, scale: 4, default: "0.0", null: false
    t.decimal "down_pct", precision: 7, scale: 4, default: "0.0", null: false
    t.integer "failed_samples", default: 0, null: false
    t.integer "p95_latency_ms"
    t.integer "service_id", null: false
    t.integer "total_samples", default: 0, null: false
    t.datetime "updated_at"
    t.decimal "uptime_pct", precision: 7, scale: 4, default: "0.0", null: false
    t.datetime "window_end", null: false
    t.string "window_key", null: false
    t.datetime "window_start", null: false
    t.index ["account_id"], name: "index_sla_rollups_on_account_id"
    t.index ["service_id", "window_key"], name: "index_sla_rollups_on_service_id_and_window_key", unique: true
    t.index ["service_id"], name: "index_sla_rollups_on_service_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", limit: 1024, null: false
    t.integer "channel_hash", limit: 8, null: false
    t.datetime "created_at", null: false
    t.binary "payload", limit: 536870912, null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", limit: 4, null: false
    t.datetime "created_at", null: false
    t.binary "key", limit: 1024, null: false
    t.integer "key_hash", limit: 8, null: false
    t.binary "value", limit: 536870912, null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  add_foreign_key "audit_logs", "accounts"
  add_foreign_key "check_results", "accounts"
  add_foreign_key "check_results", "service_checks"
  add_foreign_key "check_results", "services"
  add_foreign_key "health_events", "accounts"
  add_foreign_key "health_events", "monitor_source_bindings"
  add_foreign_key "health_events", "monitors"
  add_foreign_key "health_events", "services"
  add_foreign_key "heartbeat_tokens", "accounts"
  add_foreign_key "heartbeat_tokens", "monitors"
  add_foreign_key "heartbeat_tokens", "services"
  add_foreign_key "incident_events", "accounts"
  add_foreign_key "incident_events", "incidents"
  add_foreign_key "incidents", "accounts"
  add_foreign_key "incidents", "check_results", column: "first_check_result_id"
  add_foreign_key "incidents", "check_results", column: "last_check_result_id"
  add_foreign_key "incidents", "health_events", column: "first_health_event_id"
  add_foreign_key "incidents", "health_events", column: "last_health_event_id"
  add_foreign_key "incidents", "monitors"
  add_foreign_key "incidents", "service_checks"
  add_foreign_key "incidents", "services"
  add_foreign_key "integration_endpoints", "accounts"
  add_foreign_key "integration_event_ingresses", "accounts"
  add_foreign_key "integration_event_ingresses", "health_events"
  add_foreign_key "integration_event_ingresses", "integration_endpoints"
  add_foreign_key "integration_event_ingresses", "monitor_source_bindings"
  add_foreign_key "monitor_sla_rollups", "accounts"
  add_foreign_key "monitor_sla_rollups", "monitors"
  add_foreign_key "monitor_source_bindings", "accounts"
  add_foreign_key "monitor_source_bindings", "integration_endpoints"
  add_foreign_key "monitor_source_bindings", "monitors"
  add_foreign_key "monitors", "accounts"
  add_foreign_key "monitors", "services"
  add_foreign_key "notification_channels", "accounts"
  add_foreign_key "notification_deliveries", "accounts"
  add_foreign_key "notification_deliveries", "incidents"
  add_foreign_key "notification_deliveries", "notification_channels"
  add_foreign_key "service_checks", "accounts"
  add_foreign_key "service_checks", "health_check_types"
  add_foreign_key "service_checks", "services"
  add_foreign_key "service_notifications", "accounts"
  add_foreign_key "service_notifications", "notification_channels"
  add_foreign_key "service_notifications", "services"
  add_foreign_key "services", "accounts"
  add_foreign_key "settings", "accounts"
  add_foreign_key "sla_rollups", "accounts"
  add_foreign_key "sla_rollups", "services"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
