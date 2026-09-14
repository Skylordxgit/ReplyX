require 'rails_helper'

RSpec.describe Reports::AgentQualityMetricsCalculator do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:range) { 1.week.ago.beginning_of_day..Time.current.end_of_day }

  let(:calculator) do
    described_class.new(
      account: account,
      agent_ids: [agent.id],
      range: range,
      params: {},
      scoped_conversations: account.conversations,
      scoped_events: account.reporting_events.where(created_at: range),
      closed_counts: { agent.id => 2 },
      reopened_counts: { agent.id => 1 }
    )
  end

  describe '#calculate' do
    it 'calculates reopen rate from closed and reopened counts' do
      results = calculator.calculate
      expect(results[:reopen_rates][agent.id]).to eq(50.0)
    end

    it 'returns nil reopen rate when closed count is 0' do
      empty_calc = described_class.new(
        account: account, agent_ids: [agent.id], range: range, params: {},
        scoped_conversations: account.conversations, scoped_events: account.reporting_events.where(created_at: range),
        closed_counts: { agent.id => 0 }, reopened_counts: { agent.id => 0 }
      )
      expect(empty_calc.calculate[:reopen_rates][agent.id]).to be_nil
    end

    it 'calculates CSAT score and positive/negative ratings' do
      conv1 = create(:conversation, account: account, inbox: inbox, assignee: agent, status: :resolved)
      msg1 = create(:message, account: account, inbox: inbox, conversation: conv1, message_type: :outgoing, sender: agent)
      create(:csat_survey_response, account: account, conversation: conv1, message: msg1, assigned_agent: agent, rating: 5, created_at: Time.current)

      conv2 = create(:conversation, account: account, inbox: inbox, assignee: agent, status: :resolved)
      msg2 = create(:message, account: account, inbox: inbox, conversation: conv2, message_type: :outgoing, sender: agent)
      create(:csat_survey_response, account: account, conversation: conv2, message: msg2, assigned_agent: agent, rating: 2, created_at: Time.current)

      results = calculator.calculate
      expect(results[:csat_scores][agent.id]).to eq(50.0)
      expect(results[:positive_ratings][agent.id]).to eq(1)
      expect(results[:negative_ratings][agent.id]).to eq(1)
    end
  end
end
