# Computes per-agent timing metrics with average, median and p90 aggregates.
#
# Every metric is attributed to the agent who performed the action via
# reporting_events.user_id, so a conversation that changes hands contributes each
# timing to the agent responsible for it rather than to the current assignee.
#
# Bot and automation replies never produce first_response/reply_time events (see
# Message#valid_first_reply? and Message#bot_response?), so those metrics exclude
# bots at the source. conversation_assigned is only written for human assignees.
class V2::Reports::AgentTimingMetricsBuilder
  include DateRangeHelper

  pattr_initialize [:account!, :params!]

  EVENT_BACKED_METRICS = {
    first_customer_response_time: 'first_response',
    response_time: 'reply_time',
    resolution_time: 'conversation_resolved',
    chat_duration: 'conversation_resolved',
    queue_waiting_time: 'conversation_assigned'
  }.freeze

  CUSTOM_TIMING_METRICS = %i[
    assignment_first_response_time
    avg_handling_time
    active_handling_time
  ].freeze

  AGGREGATES = %i[average median p90].freeze

  REPLY_EVENTS = %w[first_response reply_time].freeze

  def self.metric_keys
    EVENT_BACKED_METRICS.keys + CUSTOM_TIMING_METRICS
  end

  def build
    metrics = EVENT_BACKED_METRICS.transform_values { |event_name| timings_for(event_name) }
    metrics[:assignment_first_response_time] = assignment_response_timings
    metrics[:avg_handling_time] = handling_timings
    metrics[:active_handling_time] = active_handling_timings
    metrics
  end

  private

  # Aggregates a single reporting_events name per agent in one pass.
  def timings_for(event_name)
    scoped_events
      .where(name: event_name)
      .group(:user_id)
      .pluck(Arel.sql("reporting_events.user_id, #{aggregate_selects(value_column)}"))
      .to_h { |user_id, *values| [user_id, build_stats(values)] }
  end

  # Time between an agent being assigned a conversation and their next human reply.
  def assignment_response_timings
    paired = assignments_scope.select(
      'reporting_events.user_id AS user_id',
      "(#{next_reply_subquery}) - EXTRACT(EPOCH FROM reporting_events.event_end_time) AS seconds"
    )

    fetch_aggregated_stats(paired)
  end

  # Handling duration from an agent's assignment to resolution (falls back to resolve value).
  def handling_timings
    handling_sub = scoped_events
                   .where(name: 'conversation_resolved')
                   .select('reporting_events.user_id AS user_id', "#{handling_seconds_sql} AS seconds")

    fetch_aggregated_stats(handling_sub)
  end

  # Sum of active response time per handled conversation for each agent.
  def active_handling_timings
    active_sub = scoped_events
                 .where(name: REPLY_EVENTS)
                 .group(:user_id, :conversation_id)
                 .select("reporting_events.user_id AS user_id, SUM(#{value_column}) AS seconds")

    fetch_aggregated_stats(active_sub)
  end

  def fetch_aggregated_stats(subquery_relation)
    ReportingEvent
      .connection
      .select_all(aggregate_over(subquery_relation).to_sql)
      .to_h { |row| [row['user_id'], build_stats([row['average'], row['median'], row['p90']])] }
  end

  def handling_seconds_sql
    <<~SQL.squish
      COALESCE(
        EXTRACT(EPOCH FROM (reporting_events.event_end_time - (
          SELECT MAX(ca.event_end_time)
          FROM reporting_events ca
          WHERE ca.conversation_id = reporting_events.conversation_id
            AND ca.user_id = reporting_events.user_id
            AND ca.name = 'conversation_assigned'
            AND ca.event_end_time <= reporting_events.event_end_time
        ))),
        #{value_column}
      )
    SQL
  end

  def assignments_scope
    scope = account.reporting_events
                   .where(name: 'conversation_assigned', created_at: range)
                   .where.not(user_id: nil)
    scope = scope.joins(:conversation).where(conversations: { team_id: team_id }) if team_id.present?
    scope = scope.where(user_id: user_id) if user_id.present?
    scope
  end

  def next_reply_subquery
    sanitize(
      <<~SQL.squish,
        SELECT MIN(EXTRACT(EPOCH FROM replies.event_end_time))
        FROM reporting_events replies
        WHERE replies.conversation_id = reporting_events.conversation_id
          AND replies.user_id = reporting_events.user_id
          AND replies.name IN (:reply_events)
          AND replies.event_end_time >= reporting_events.event_end_time
      SQL
      reply_events: REPLY_EVENTS
    )
  end

  def aggregate_over(paired)
    ReportingEvent
      .unscoped
      .from(paired, :paired)
      .where.not(paired: { seconds: nil })
      .group('paired.user_id')
      .select("paired.user_id AS user_id, #{aggregate_selects('paired.seconds')}")
  end

  def aggregate_selects(column)
    [
      "AVG(#{column}) AS average",
      "PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY #{column}) AS median",
      "PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY #{column}) AS p90"
    ].join(', ')
  end

  def build_stats(values)
    AGGREGATES.zip(values).to_h { |key, value| [key, value&.to_f&.round(1)] }
  end

  def scoped_events
    scope = account.reporting_events.where(created_at: range).where.not(user_id: nil)
    scope = scope.joins(:conversation).where(conversations: { team_id: team_id }) if team_id.present?
    scope = scope.where(user_id: user_id) if user_id.present?
    scope
  end

  def sanitize(sql, **bindings)
    ActiveRecord::Base.sanitize_sql_array([sql, bindings])
  end

  def value_column
    business_hours? ? 'reporting_events.value_in_business_hours' : 'reporting_events.value'
  end

  def business_hours?
    ActiveModel::Type::Boolean.new.cast(params[:business_hours])
  end

  def team_id
    params[:team_id]
  end

  def user_id
    params[:user_id]
  end
end
