# Computes agent quality metrics: CSAT ratings, Reopen Rate, First Contact Resolution, and SLA metrics.
class Reports::AgentQualityMetricsCalculator
  pattr_initialize [
    :account!, :agent_ids!, :range!, :params!,
    :scoped_conversations!, :scoped_events!, :closed_counts!, :reopened_counts!
  ]

  def calculate
    {
      csat_scores: csat_metrics[:scores],
      positive_ratings: csat_metrics[:positive],
      negative_ratings: csat_metrics[:negative],
      reopen_rates: reopen_rates,
      fcr_rates: fcr_rates,
      sla_met_counts: sla_metrics[:met],
      sla_missed_counts: sla_metrics[:missed]
    }
  end

  private

  def csat_metrics
    @csat_metrics ||= build_csat_metrics
  end

  def build_csat_metrics
    total_by_agent = csat_scope.group(:assigned_agent_id).count
    pos_by_agent = csat_scope.where(rating: [4, 5]).group(:assigned_agent_id).count
    neg_by_agent = csat_scope.where(rating: [1, 2]).group(:assigned_agent_id).count

    scores = {}
    positives = {}
    negatives = {}

    total_by_agent.each do |aid, total|
      next unless total.positive?

      pos = pos_by_agent[aid] || 0
      scores[aid] = ((pos.to_f / total) * 100).round(1)
      positives[aid] = pos
      negatives[aid] = neg_by_agent[aid] || 0
    end

    { scores: scores, positive: positives, negative: negatives }
  end

  def reopen_rates
    agent_ids.each_with_object({}) do |aid, rates|
      closed = closed_counts[aid] || 0
      reopened = reopened_counts[aid] || 0
      rates[aid] = closed.positive? ? ((reopened.to_f / closed) * 100).round(1) : nil
    end
  end

  def fcr_rates
    resolved_convs = scoped_conversations.where(status: :resolved, created_at: range).where.not(assignee_id: nil)
    conv_ids = resolved_convs.pluck(:id, :assignee_id)
    return {} if conv_ids.empty?

    msg_counts = account.messages.unscope(:order)
                        .where(conversation_id: conv_ids.map(&:first), message_type: :outgoing, sender_type: 'User', private: false)
                        .group(:conversation_id).count

    reopened_ids = scoped_events.where(name: 'conversation_opened').where('reporting_events.value > 0').distinct.pluck(:conversation_id).to_set
    map_fcr_rates(conv_ids, msg_counts, reopened_ids)
  end

  def map_fcr_rates(conv_ids, msg_counts, reopened_ids)
    resolved = Hash.new(0)
    fcr = Hash.new(0)

    conv_ids.each do |cid, aid|
      resolved[aid] += 1
      fcr[aid] += 1 if msg_counts[cid] == 1 && reopened_ids.exclude?(cid)
    end

    agent_ids.each_with_object({}) do |aid, rates|
      total = resolved[aid] || 0
      rates[aid] = total.positive? ? ((fcr[aid].to_f / total) * 100).round(1) : nil
    end
  end

  def sla_metrics
    @sla_metrics ||= sla_supported? ? build_sla_counts : { met: {}, missed: {} }
  end

  def sla_supported?
    defined?(AppliedSla) && account.respond_to?(:applied_slas)
  end

  def build_sla_counts
    total_slas = sla_scope.group('conversations.assignee_id').count
    met_slas = sla_scope.where(sla_status: :hit).group('conversations.assignee_id').count
    missed_slas = sla_scope.where(sla_status: %i[missed active_with_misses]).group('conversations.assignee_id').count

    met = {}
    missed = {}
    agent_ids.each do |aid|
      next unless total_slas[aid]&.positive?

      met[aid] = met_slas[aid] || 0
      missed[aid] = missed_slas[aid] || 0
    end

    { met: met, missed: missed }
  end

  def csat_scope
    scope = account.csat_survey_responses.where(created_at: range).where.not(assigned_agent_id: nil)
    scope = Reports::ConversationFilterApplicator.apply_to_joined(scope, params)
    scope = scope.where(assigned_agent_id: params[:user_id]) if params[:user_id].present?
    scope
  end

  def sla_scope
    scope = account.applied_slas.where(created_at: range).joins(:conversation).where.not(conversations: { assignee_id: nil })
    scope = Reports::ConversationFilterApplicator.apply_to_joined(scope, params)
    scope = scope.where(conversations: { assignee_id: params[:user_id] }) if params[:user_id].present?
    scope
  end
end
