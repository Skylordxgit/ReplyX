# == Schema Information
#
# Table name: canned_responses
#
#  id         :integer          not null, primary key
#  content    :text
#  short_code :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :integer          not null
#

class CannedResponse < ApplicationRecord
  include AccountCacheRevalidator

  enum :access_scope, { everyone: 0, specific_teams: 1, specific_users: 2, only_me: 3 }, validate: true

  validates :content, presence: true
  validates :short_code, presence: true
  validates :account, presence: true
  validates :short_code, uniqueness: { scope: :account_id }
  validates :allowed_teams, presence: true, if: :specific_teams?
  validates :allowed_users, presence: true, if: :specific_users?
  validates :creator, presence: true, if: :only_me?

  belongs_to :account
  belongs_to :creator, class_name: 'User', optional: true
  has_and_belongs_to_many :allowed_teams, class_name: 'Team', join_table: :canned_response_teams
  has_and_belongs_to_many :allowed_users, class_name: 'User', join_table: :canned_response_users

  scope :accessible_to, lambda { |user, account_user|
    next all if account_user.administrator?

    where(
      <<~SQL.squish, user_id: user.id
        canned_responses.access_scope = #{access_scopes[:everyone]}
        OR (canned_responses.access_scope = #{access_scopes[:only_me]} AND canned_responses.creator_id = :user_id)
        OR (canned_responses.access_scope = #{access_scopes[:specific_users]} AND EXISTS (
          SELECT 1 FROM canned_response_users
          WHERE canned_response_users.canned_response_id = canned_responses.id
            AND canned_response_users.user_id = :user_id
        ))
        OR (canned_responses.access_scope = #{access_scopes[:specific_teams]} AND EXISTS (
          SELECT 1 FROM canned_response_teams
          INNER JOIN teams ON teams.id = canned_response_teams.team_id
          INNER JOIN team_members ON team_members.team_id = teams.id
          WHERE canned_response_teams.canned_response_id = canned_responses.id
            AND teams.account_id = canned_responses.account_id
            AND team_members.user_id = :user_id
        ))
      SQL
    )
  }

  scope :order_by_search, lambda { |search|
    short_code_starts_with = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 1', "#{search}%"])
    short_code_like = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 0.5', "%#{search}%"])
    content_like = sanitize_sql_array(['WHEN content ILIKE ? THEN 0.2', "%#{search}%"])

    order_clause = "CASE #{short_code_starts_with} #{short_code_like} #{content_like} ELSE 0 END"

    order(Arel.sql(order_clause) => :desc)
  }
end
