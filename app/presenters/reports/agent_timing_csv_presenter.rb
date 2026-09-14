# Flattens the nested timing metrics returned by V2::Reports::AgentTimingMetricsBuilder
# into the flat header/value columns the agent CSV export expects.
class Reports::AgentTimingCsvPresenter
  def self.headers
    each_column.map do |metric, aggregate|
      "#{I18n.t("reports.agent_csv.#{metric}")} (#{I18n.t("reports.agent_csv.aggregates.#{aggregate}")})"
    end
  end

  def self.values(report)
    each_column.map do |metric, aggregate|
      Reports::TimeFormatPresenter.new(report.fetch(metric, {})[aggregate]).format
    end
  end

  def self.each_column
    V2::Reports::AgentTimingMetricsBuilder.metric_keys.flat_map do |metric|
      V2::Reports::AgentTimingMetricsBuilder::AGGREGATES.map { |aggregate| [metric, aggregate] }
    end
  end
  private_class_method :each_column
end
