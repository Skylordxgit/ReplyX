require 'rails_helper'

RSpec.describe V2::Reports::AgentTimingMetricsBuilder do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:business_hours) { false }

  let(:params) do
    {
      since: 1.week.ago.beginning_of_day,
      until: Time.current.end_of_day,
      business_hours: business_hours
    }
  end

  let(:builder) { described_class.new(account: account, params: params) }

  def add_event(name:, user:, conversation:, value: 0, at: Time.current)
    create(
      :reporting_event,
      account: account,
      inbox: inbox,
      conversation: conversation,
      user: user,
      name: name,
      value: value,
      value_in_business_hours: value,
      created_at: 1.day.ago,
      event_start_time: at - value.seconds,
      event_end_time: at
    )
  end

  describe 'aggregates' do
    before do
      # values 10, 20, 30, 40, 100 => avg 40, median 30, p90 76
      [10, 20, 30, 40, 100].each do |value|
        conversation = create(:conversation, account: account, inbox: inbox, assignee: agent)
        add_event(name: 'reply_time', user: agent, value: value, conversation: conversation)
      end
    end

    it 'returns average, median and p90 for response time' do
      stats = builder.build[:response_time][agent.id]

      expect(stats[:average]).to eq(40.0)
      expect(stats[:median]).to eq(30.0)
      expect(stats[:p90]).to eq(76.0)
    end

    context 'when business hours is enabled' do
      let(:business_hours) { true }

      it 'aggregates the business hours column' do
        stats = builder.build[:response_time][agent.id]

        expect(stats[:average]).to eq(40.0)
      end
    end
  end

  describe 'first customer response time' do
    it 'is derived from first_response events' do
      conversation = create(:conversation, account: account, inbox: inbox, assignee: agent)
      add_event(name: 'first_response', user: agent, value: 45, conversation: conversation)

      stats = builder.build[:first_customer_response_time][agent.id]

      expect(stats[:average]).to eq(45.0)
      expect(stats[:median]).to eq(45.0)
    end
  end

  describe 'resolution time and chat duration' do
    it 'are derived from conversation_resolved events' do
      conversation = create(:conversation, account: account, inbox: inbox, assignee: agent)
      add_event(name: 'conversation_resolved', user: agent, value: 600, conversation: conversation)

      report = builder.build

      expect(report[:resolution_time][agent.id][:average]).to eq(600.0)
      expect(report[:chat_duration][agent.id][:average]).to eq(600.0)
    end
  end

  describe 'queue waiting time' do
    it 'is derived from conversation_assigned events' do
      conversation = create(:conversation, account: account, inbox: inbox, assignee: agent)
      add_event(name: 'conversation_assigned', user: agent, value: 45, conversation: conversation)

      stats = builder.build[:queue_waiting_time][agent.id]

      expect(stats[:average]).to eq(45.0)
      expect(stats[:median]).to eq(45.0)
    end
  end

  describe 'active handling time' do
    it 'sums response times per conversation for the agent' do
      conversation = create(:conversation, account: account, inbox: inbox, assignee: agent)
      add_event(name: 'first_response', user: agent, value: 30, conversation: conversation)
      add_event(name: 'reply_time', user: agent, value: 50, conversation: conversation)

      stats = builder.build[:active_handling_time][agent.id]

      expect(stats[:average]).to eq(80.0)
      expect(stats[:median]).to eq(80.0)
    end
  end

  describe 'handling time' do
    let(:base) { 2.days.ago.change(usec: 0) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox, created_at: base) }

    it 'measures from assignment to resolution' do
      add_event(name: 'conversation_assigned', user: agent, conversation: conversation, at: base + 30.seconds)
      add_event(name: 'conversation_resolved', user: agent, value: 300, conversation: conversation, at: base + 300.seconds)

      stats = builder.build[:avg_handling_time][agent.id]

      expect(stats[:average]).to eq(270.0)
    end

    it 'falls back to resolve value if no assignment event exists' do
      add_event(name: 'conversation_resolved', user: agent, value: 200, conversation: conversation, at: base + 200.seconds)

      stats = builder.build[:avg_handling_time][agent.id]

      expect(stats[:average]).to eq(200.0)
    end
  end

  describe 'assignment first response time' do
    let(:base) { 2.days.ago.change(usec: 0) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox, created_at: base) }

    it 'measures each agent from their own assignment when reassigned' do
      add_event(name: 'conversation_assigned', user: agent, conversation: conversation, at: base)
      add_event(name: 'first_response', user: agent, conversation: conversation, at: base + 100.seconds)

      add_event(name: 'conversation_assigned', user: other_agent, conversation: conversation, at: base + 300.seconds)
      add_event(name: 'reply_time', user: other_agent, conversation: conversation, at: base + 360.seconds)

      stats = builder.build[:assignment_first_response_time]

      expect(stats[agent.id][:average]).to eq(100.0)
      expect(stats[other_agent.id][:average]).to eq(60.0)
    end

    it 'ignores assignments that never received a reply' do
      add_event(name: 'conversation_assigned', user: agent, conversation: conversation, at: base)

      expect(builder.build[:assignment_first_response_time][agent.id]).to be_nil
    end
  end

  describe 'filters' do
    let(:team) { create(:team, account: account) }

    it 'scopes metrics to a single agent' do
      conversation = create(:conversation, account: account, inbox: inbox, assignee: agent)
      add_event(name: 'reply_time', user: agent, value: 10, conversation: conversation)

      other_conversation = create(:conversation, account: account, inbox: inbox, assignee: other_agent)
      add_event(name: 'reply_time', user: other_agent, value: 90, conversation: other_conversation)

      report = described_class.new(account: account, params: params.merge(user_id: agent.id)).build

      expect(report[:response_time].keys).to eq([agent.id])
    end

    it 'scopes metrics to a team' do
      in_team = create(:conversation, account: account, inbox: inbox, team: team, assignee: agent)
      add_event(name: 'reply_time', user: agent, value: 10, conversation: in_team)

      outside_team = create(:conversation, account: account, inbox: inbox, assignee: other_agent)
      add_event(name: 'reply_time', user: other_agent, value: 90, conversation: outside_team)

      report = described_class.new(account: account, params: params.merge(team_id: team.id)).build

      expect(report[:response_time].keys).to eq([agent.id])
    end
  end
end
