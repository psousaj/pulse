class RemoveLegacyAuthSchema < ActiveRecord::Migration[8.1]
  def up
    add_column :audit_logs, :actor_ref, :string unless column_exists?(:audit_logs, :actor_ref)
    add_column :incidents, :acknowledged_by_ref, :string unless column_exists?(:incidents, :acknowledged_by_ref)
    add_column :incidents, :resolved_by_ref, :string unless column_exists?(:incidents, :resolved_by_ref)

    migrate_actor_references
    remove_legacy_incident_user_references
    remove_legacy_audit_log_user_reference

    drop_table :api_access_tokens, if_exists: true
    drop_table :api_refresh_tokens, if_exists: true
    drop_table :api_clients, if_exists: true
    drop_table :users, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Legacy auth schema cleanup cannot be reversed automatically"
  end

  private

  def migrate_actor_references
    if column_exists?(:audit_logs, :user_id)
      execute <<~SQL
        UPDATE audit_logs
        SET actor_ref = COALESCE(actor_ref, 'user:' || user_id)
        WHERE user_id IS NOT NULL
      SQL
    end

    if column_exists?(:incidents, :acknowledged_by_user_id)
      execute <<~SQL
        UPDATE incidents
        SET acknowledged_by_ref = COALESCE(acknowledged_by_ref, 'user:' || acknowledged_by_user_id)
        WHERE acknowledged_by_user_id IS NOT NULL
      SQL
    end

    if column_exists?(:incidents, :resolved_by_user_id)
      execute <<~SQL
        UPDATE incidents
        SET resolved_by_ref = COALESCE(resolved_by_ref, 'user:' || resolved_by_user_id)
        WHERE resolved_by_user_id IS NOT NULL
      SQL
    end
  end

  def remove_legacy_incident_user_references
    if foreign_key_exists?(:incidents, :users, column: :acknowledged_by_user_id)
      remove_foreign_key :incidents, column: :acknowledged_by_user_id
    end

    if foreign_key_exists?(:incidents, :users, column: :resolved_by_user_id)
      remove_foreign_key :incidents, column: :resolved_by_user_id
    end

    remove_index :incidents, :acknowledged_by_user_id if index_exists?(:incidents, :acknowledged_by_user_id)
    remove_index :incidents, :resolved_by_user_id if index_exists?(:incidents, :resolved_by_user_id)

    remove_column :incidents, :acknowledged_by_user_id if column_exists?(:incidents, :acknowledged_by_user_id)
    remove_column :incidents, :resolved_by_user_id if column_exists?(:incidents, :resolved_by_user_id)
  end

  def remove_legacy_audit_log_user_reference
    if foreign_key_exists?(:audit_logs, :users)
      remove_foreign_key :audit_logs, :users
    end

    remove_index :audit_logs, :user_id if index_exists?(:audit_logs, :user_id)
    remove_column :audit_logs, :user_id if column_exists?(:audit_logs, :user_id)
  end
end