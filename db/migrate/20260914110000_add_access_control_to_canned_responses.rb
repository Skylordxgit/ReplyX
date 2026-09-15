class AddAccessControlToCannedResponses < ActiveRecord::Migration[7.1]
  def change
    add_column :canned_responses, :access_scope, :integer, default: 0, null: false
    add_reference :canned_responses, :creator, foreign_key: { to_table: :users, on_delete: :nullify }, index: true

    create_table :canned_response_teams, id: false do |t|
      t.references :canned_response, null: false, foreign_key: { on_delete: :cascade }, type: :integer
      t.references :team, null: false, foreign_key: { on_delete: :cascade }
    end
    add_index :canned_response_teams, [:canned_response_id, :team_id], unique: true

    create_table :canned_response_users, id: false do |t|
      t.references :canned_response, null: false, foreign_key: { on_delete: :cascade }, type: :integer
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
    end
    add_index :canned_response_users, [:canned_response_id, :user_id], unique: true
    add_index :canned_responses, [:account_id, :access_scope]
  end
end
