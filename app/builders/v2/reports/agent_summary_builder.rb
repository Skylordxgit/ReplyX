class V2::Reports::AgentSummaryBuilder < V2::Reports::BaseSummaryBuilder
  pattr_initialize [:account!, :params!]

  AVERAGE_EVENTS = {
    avg_first_response_time: 'first_response',
    avg_resolution_time: 'conversation_resolved',
    avg_reply_time: 'reply_time'
  }.freeze

  COUNT_SOURCES = {
    conversations_count: :assigned_counts, replied_count: :replied_counts,
    open_count: :open_counts, pending_count: :pending_counts,
    closed_count: :closed_counts, reopened_count: :reopened_counts,
    current_workload: :workload_counts, messages_sent: :messages_sent_counts,
    internal_notes: :internal_notes_counts, transfers: :transfer_counts,
    reassignments: :reassignment_counts
  }.freeze

  QUALITY_MAP = {
    csat_score: :csat_scores, positive_ratings: :positive_ratings,
    negative_ratings: :negative_ratings, reopen_rate: :reopen_rates,
    fcr_rate: :fcr_rates, sla_met: :sla_met_counts, sla_missed: :sla_missed_counts
  }.freeze

  def build
    load_conversation_counts
    load_replied_and_reopened_counts
    load_message_and_activity_counts
    load_average_times
    load_active_hours_and_rates
    load_timing_metrics
    load_quality_metrics
    prepare_report
  end

  private

  attr_reader :assigned_counts, :open_counts, :pending_counts, :closed_counts,
              :workload_counts, :replied_counts, :reopened_counts,
              :messages_sent_counts, :internal_notes_counts,
              :transfer_counts, :reassignment_counts,
              :active_hours, :chats_per_active_hour, :closed_chats_per_active_hour,
              :average_times, :timing_metrics, :quality_metrics

  def load_timing_metrics
    @timing_metrics = V2::Reports::AgentTimingMetricsBuilder.new(account: account, params: params).build
  end

  def load_conversation_counts
    created_in_range = scoped_conversations.where(created_at: range).where.not(assignee_id: nil)

    @assigned_counts = created_in_range.group(:assignee_id).count
    @open_counts = created_in_range.open.group(:assignee_id).count
    @pending_counts = created_in_range.pending.group(:assignee_id).count
    @closed_counts = created_in_range.resolved.group(:assignee_id).count

    @workload_counts = scoped_conversations.where(status: %i[open pending])
                                           .where.not(assignee_id: nil)
                                           .group(:assignee_id)
                                           .count
  end

  def load_replied_and_reopened_counts
    @replied_counts = scoped_events.where(name: %w[first_response reply_time])
                                   .group(:user_id)
                                   .distinct
                                   .count(:conversation_id)

    @reopened_counts = scoped_events.where(name: 'conversation_opened')
                                    .where('reporting_events.value > 0')
                                    .group(:user_id)
                                    .distinct
                                    .count(:conversation_id)
  end

  def load_message_and_activity_counts
    msg_scope = scoped_messages
    @messages_sent_counts = msg_scope.where(message_type: :outgoing, private: false).group(:sender_id).count
    @internal_notes_counts = msg_scope.where(private: true).group(:sender_id).count
    @transfer_counts = scoped_events.where(name: 'conversation_transferred').group(:user_id).count
    @reassignment_counts = scoped_events.where(name: 'conversation_reassigned').group(:user_id).count
  end

  def scoped_messages
    scope = account.messages.unscope(:order).where(created_at: range, sender_type: 'User').where.not(sender_id: nil)
    scope = Reports::ConversationFilterApplicator.apply_to_joined(scope, params)
    scope = scope.where(sender_id: user_id) if user_id.present?
    scope
  end

  def load_average_times
    selects = AVERAGE_EVENTS.map do |key, event_name|
      "AVG(CASE WHEN reporting_events.name = '#{event_name}' THEN reporting_events.#{value_column} END) AS #{key}"
    end

    @average_times = scoped_events.where(name: AVERAGE_EVENTS.values)
                                  .group(:user_id)
                                  .select('reporting_events.user_id', *selects)
                                  .index_by(&:user_id)
  end

  def load_active_hours_and_rates
    msg_stamps = scoped_messages.group(:sender_id).pluck(:sender_id, Arel.sql('array_agg(messages.created_at)')).to_h
    ev_stamps = scoped_events.group(:user_id).pluck(:user_id, Arel.sql('array_agg(reporting_events.created_at)')).to_h

    @active_hours = {}
    @chats_per_active_hour = {}
    @closed_chats_per_active_hour = {}

    agent_ids.each { |id| process_agent_rate(id, (msg_stamps[id] || []) + (ev_stamps[id] || [])) }
  end

  def process_agent_rate(agent_id, timestamps)
    hours = Reports::AgentActivityCalculator.active_hours(timestamps)
    handled = replied_counts[agent_id] || assigned_counts[agent_id] || 0

    @active_hours[agent_id] = hours
    @chats_per_active_hour[agent_id] = Reports::AgentActivityCalculator.rate(handled, hours)
    @closed_chats_per_active_hour[agent_id] = Reports::AgentActivityCalculator.rate(closed_counts[agent_id] || 0, hours)
  end

  def load_quality_metrics
    @quality_metrics = Reports::AgentQualityMetricsCalculator.new(
      account: account, agent_ids: agent_ids, range: range, params: params,
      scoped_conversations: scoped_conversations, scoped_events: scoped_events,
      closed_counts: closed_counts, reopened_counts: reopened_counts
    ).calculate
  end

  def scoped_conversations
    Reports::ConversationFilterApplicator.apply_to_conversations(account.conversations, params)
  end

  def scoped_events
    scope = account.reporting_events.where(created_at: range).where.not(user_id: nil)
    scope = Reports::ConversationFilterApplicator.apply_to_joined(scope, params)
    scope = scope.where(user_id: user_id) if user_id.present?
    scope
  end

  def prepare_report
    agent_ids.map { |agent_id| build_agent_stats(agent_id) }
  end

  def agent_ids
    ids = account.account_users.pluck(:user_id)
    ids &= account.teams.find(team_id).team_members.pluck(:user_id) if team_id.present?
    ids &= [user_id.to_i] if user_id.present?
    ids
  end

  def build_agent_stats(agent_id)
    averages = average_times[agent_id]
    int_counts = COUNT_SOURCES.transform_values { |source| send(source)[agent_id] || 0 }
    opt_metrics = build_optional_metrics(agent_id)

    {
      id: agent_id,
      **int_counts,
      **opt_metrics,
      avg_resolution_time: averages&.avg_resolution_time,
      avg_first_response_time: averages&.avg_first_response_time,
      avg_reply_time: averages&.avg_reply_time
    }.merge(timing_metrics_for(agent_id))
  end

  def build_optional_metrics(agent_id)
    quality = QUALITY_MAP.transform_values { |source| quality_metrics[source][agent_id] }

    {
      active_hours: active_hours[agent_id],
      chats_per_active_hour: chats_per_active_hour[agent_id],
      closed_chats_per_active_hour: closed_chats_per_active_hour[agent_id],
      **quality
    }
  end

  def timing_metrics_for(agent_id)
    timing_metrics.transform_values do |per_agent|
      per_agent[agent_id] || V2::Reports::AgentTimingMetricsBuilder::AGGREGATES.index_with(nil)
    end
  end

  def value_column
    ActiveModel::Type::Boolean.new.cast(params[:business_hours]) ? 'value_in_business_hours' : 'value'
  end

  def team_id = params[:team_id]
  def user_id = params[:user_id]
  def group_by_key = :user_id
end
