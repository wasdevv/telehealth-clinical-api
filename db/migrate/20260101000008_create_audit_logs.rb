class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :action, null: false
      t.string :resource_type, null: false
      t.bigint :resource_id, null: false
      t.string :ip_address

      # Append-only: there is no updated_at because a row is never revised.
      t.datetime :created_at, null: false
    end

    add_index :audit_logs, %i[resource_type resource_id created_at]
    add_index :audit_logs, %i[user_id created_at]
  end
end
