class Api::V2::Accounts::LiveReportsController < Api::V1::Accounts::BaseController
  POSITIVE_CSAT_RATINGS = [4, 5].freeze

  before_action :load_conversations, only: [:conversation_metrics, :grouped_conversation_metrics]
  before_action :set_group_scope, only: [:grouped_conversation_metrics]

  before_action :check_authorization

  def conversation_metrics
    render json: conversation_status_counts.merge(
      avg_first_response_time: average_reporting_event(:first_response),
      avg_resolution_time: average_reporting_event(:conversation_resolved),
      csat: csat_score
    )
  end

  def grouped_conversation_metrics
    count_by_group = @conversations.open.group(@group_scope).count
    unattended_by_group = @conversations.open.unattended.group(@group_scope).count
    unassigned_by_group = @conversations.open.unassigned.group(@group_scope).count

    group_metrics = count_by_group.map do |group_id, count|
      metric = {
        open: count,
        unattended: unattended_by_group[group_id] || 0,
        unassigned: unassigned_by_group[group_id] || 0
      }
      metric[@group_scope] = group_id
      metric
    end

    render json: group_metrics
  end

  private

  def check_authorization
    authorize :report, :view?
  end

  # Resolves every status bucket in a single grouped query instead of one COUNT per status.
  def conversation_status_counts
    counts_by_status = @conversations.group(:status).count
    open_scope = @conversations.open

    {
      total: counts_by_status.values.sum,
      open: counts_by_status['open'] || 0,
      unattended: open_scope.unattended.count,
      unassigned: open_scope.unassigned.count,
      pending: counts_by_status['pending'] || 0,
      resolved: counts_by_status['resolved'] || 0
    }
  end

  def average_reporting_event(event_name)
    scope = Current.account.reporting_events.where(name: event_name, account_id: Current.account.id)
    scope = scope.joins(:conversation).where(conversations: { team_id: team.id }) if team.present?
    scope.average(:value)&.to_f&.round(1)
  end

  def csat_score
    scope = Current.account.csat_survey_responses
    scope = scope.filter_by_team_id(team.id) if team.present?

    counts = scope.group(:rating).count
    total = counts.values.sum
    return if total.zero?

    positive = counts.slice(*POSITIVE_CSAT_RATINGS).values.sum
    ((positive.to_f / total) * 100).round(1)
  end

  def set_group_scope
    render json: { error: 'invalid group_by' }, status: :unprocessable_content and return unless %w[
      team_id
      assignee_id
    ].include?(permitted_params[:group_by])

    @group_scope = permitted_params[:group_by]
  end

  def team
    return unless permitted_params[:team_id]

    @team ||= Current.account.teams.find(permitted_params[:team_id])
  end

  def load_conversations
    scope = Current.account.conversations
    scope = scope.where(team_id: team.id) if team.present?
    @conversations = scope
  end

  def permitted_params
    params.permit(:team_id, :group_by)
  end
end
