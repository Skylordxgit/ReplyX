class V2::Reports::TeamSummaryBuilder < V2::Reports::BaseSummaryBuilder
  POSITIVE_CSAT_RATINGS = [4, 5].freeze

  pattr_initialize [:account!, :params!]

  def build
    load_data
    load_team_extra_metrics
    prepare_report
  end

  private

  attr_reader :conversations_count, :resolved_count,
              :avg_resolution_time, :avg_first_response_time, :avg_reply_time,
              :backlog_counts, :reopen_rates, :csat_scores

  def load_team_extra_metrics
    @backlog_counts = account.conversations.open.where.not(team_id: nil).group(:team_id).count
    @reopen_rates = build_reopen_rates
    @csat_scores = build_csat_scores
  end

  def build_reopen_rates
    reopened_by_team = account.reporting_events
                              .joins(:conversation)
                              .where(name: 'conversation_opened', created_at: range)
                              .where('reporting_events.value > 0')
                              .where.not(conversations: { team_id: nil })
                              .group('conversations.team_id')
                              .distinct
                              .count(:conversation_id)

    team_ids.to_h do |team_id|
      resolved = resolved_count[team_id] || 0
      reopened = reopened_by_team[team_id] || 0
      rate = resolved.positive? ? ((reopened.to_f / resolved) * 100).round(1) : 0.0
      [team_id, rate]
    end
  end

  def build_csat_scores
    tally = csat_tally_by_team
    tally.each_with_object({}) do |(team_id, counts), scores|
      scores[team_id] = ((counts[:positive].to_f / counts[:total]) * 100).round(1) if counts[:total].positive?
    end
  end

  # Single grouped query keyed by [team_id, rating] instead of one query per rating bucket.
  def csat_tally_by_team
    csat_scope = account.csat_survey_responses.joins(:conversation).where(created_at: range).where.not(conversations: { team_id: nil })
    counts = csat_scope.group('conversations.team_id', :rating).count

    counts.each_with_object(Hash.new { |hash, key| hash[key] = { total: 0, positive: 0 } }) do |((team_id, rating), count), tally|
      tally[team_id][:total] += count
      tally[team_id][:positive] += count if POSITIVE_CSAT_RATINGS.include?(rating)
    end
  end

  def team_ids
    @team_ids ||= account.teams.pluck(:id)
  end

  def prepare_report
    account.teams.map do |team|
      build_team_stats(team)
    end
  end

  def build_team_stats(team)
    {
      id: team.id,
      conversations_count: conversations_count[team.id] || 0,
      resolved_conversations_count: resolved_count[team.id] || 0,
      backlog_count: backlog_counts[team.id] || 0,
      avg_resolution_time: avg_resolution_time[team.id],
      avg_first_response_time: avg_first_response_time[team.id],
      avg_reply_time: avg_reply_time[team.id],
      reopen_rate: reopen_rates[team.id] || 0.0,
      csat_score: csat_scores[team.id]
    }
  end

  def group_by_key
    'conversations.team_id'
  end
end
