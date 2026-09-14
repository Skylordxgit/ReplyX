class AddForcePasswordChangeToUsersAndActiveToAccountUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :force_password_change, :boolean, default: false, null: false unless column_exists?(:users, :force_password_change)
    add_column :account_users, :active, :boolean, default: true, null: false unless column_exists?(:account_users, :active)

    add_index :account_users, [:account_id, :active] unless index_exists?(:account_users, [:account_id, :active])
  end
end
