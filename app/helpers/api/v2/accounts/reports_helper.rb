module Api::V2::Accounts::ReportsHelper
  def generate_agents_report
    reports = V2::Reports::AgentSummaryBuilder.new(account: Current.account, params: build_params(type: :agent)).build
    Current.account.users.where(id: reports.pluck(:id)).map do |agent|
      report = reports.find { |r| r[:id] == agent.id } || {}
      [agent.name] + agent_count_columns(report) +
        Reports::AgentTimingCsvPresenter.values(report) + [format_csat(report[:csat_score])]
    end
  end

  def generate_inboxes_report
    reports = V2::Reports::InboxSummaryBuilder.new(account: Current.account, params: build_params(type: :inbox)).build
    Current.account.inboxes.map do |inbox|
      report = reports.find { |r| r[:id] == inbox.id } || {}
      [inbox.name, inbox.channel&.name] + generate_readable_report_metrics(report)
    end
  end

  def generate_teams_report
    reports = V2::Reports::TeamSummaryBuilder.new(account: Current.account, params: build_params(type: :team)).build
    Current.account.teams.map do |team|
      report = reports.find { |r| r[:id] == team.id } || {}
      [team.name] + team_count_columns(report) + average_time_columns(report) +
        ["#{report[:reopen_rate] || 0}%", format_csat(report[:csat_score])]
    end
  end

  def generate_labels_report
    reports = V2::Reports::LabelSummaryBuilder.new(account: Current.account, params: build_params({})).build
    reports.map { |report| [report[:name]] + generate_readable_report_metrics(report) }
  end

  def generate_conversations_report
    builder = V2::Reports::Conversations::MetricBuilder.new(Current.account, build_params(type: :account))
    [generate_conversation_report_metrics(builder.summary)]
  end

  private

  AGENT_COUNT_KEYS = %i[
    conversations_count replied_count open_count
    pending_count closed_count reopened_count current_workload
    messages_sent internal_notes transfers reassignments
    active_hours chats_per_active_hour closed_chats_per_active_hour
    positive_ratings negative_ratings reopen_rate fcr_rate sla_met sla_missed
  ].freeze

  TEAM_COUNT_KEYS = %i[conversations_count resolved_conversations_count backlog_count].freeze
  FILTER_PARAM_KEYS = %i[team_id user_id inbox_id channel_type status priority].freeze

  def agent_count_columns(report)
    AGENT_COUNT_KEYS.map do |key|
      val = report[key]
      if %i[reopen_rate fcr_rate].include?(key)
        val ? "#{val}%" : '--'
      else
        val || (key.to_s.end_with?('_count', 's', 'workload') ? 0 : '--')
      end
    end
  end

  def team_count_columns(report)
    TEAM_COUNT_KEYS.map { |key| report[key] || 0 }
  end

  def format_csat(score)
    score ? "#{score}%" : '--'
  end

  def average_time_columns(report)
    %i[avg_first_response_time avg_resolution_time avg_reply_time].map { |k| Reports::TimeFormatPresenter.new(report[k]).format }
  end

  def build_params(base_params)
    filters = FILTER_PARAM_KEYS.each_with_object({}) { |k, h| h[k] = params[k] if params[k].present? }
    base_params.merge(filters).merge(
      since: params[:since], until: params[:until],
      business_hours: ActiveModel::Type::Boolean.new.cast(params[:business_hours])
    )
  end

  def generate_readable_report_metrics(report)
    [
      report[:conversations_count],
      Reports::TimeFormatPresenter.new(report[:avg_first_response_time]).format,
      Reports::TimeFormatPresenter.new(report[:avg_resolution_time]).format,
      Reports::TimeFormatPresenter.new(report[:avg_reply_time]).format,
      report[:resolved_conversations_count]
    ]
  end

  def generate_conversation_report_metrics(summary)
    [
      summary[:conversations_count], summary[:incoming_messages_count], summary[:outgoing_messages_count],
      Reports::TimeFormatPresenter.new(summary[:avg_first_response_time]).format,
      Reports::TimeFormatPresenter.new(summary[:avg_resolution_time]).format,
      summary[:resolutions_count], Reports::TimeFormatPresenter.new(summary[:reply_time]).format
    ]
  end
end
