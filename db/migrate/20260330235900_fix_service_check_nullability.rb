class FixServiceCheckNullability < ActiveRecord::Migration[8.1]
  def change
    change_column_null :check_results, :service_check_id, false
    change_column_null :incidents, :service_check_id, true
  end
end
