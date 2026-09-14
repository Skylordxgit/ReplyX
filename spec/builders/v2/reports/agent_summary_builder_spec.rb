require 'rails_helper'

RSpec.describe V2::Reports::AgentSummaryBuilder do
  let(:account) { create(:account) }
  let(:user1) { create(:user, account: account, role: :agent) }
  let(:user2) { create(:user, account: account, role: :agent) }

  let(:params) do
    {
      business_hours: business_hours,
      since: 1.week.ago.beginning_of_day,
      until: Time.current.end_of_day
    }
  end
  let(:builder) { described_class.new(account: account, params: params) }

  describe '#build' do
    context 'when there is agent data' do
      before do
        c1 = create(:conversation, account: account, assignee: user1, created_at: Time.current)
        c2 = create(:conversation, account: account, assignee: user2, status: :resolved, created_at: Time.current)
        create(
          :reporting_event,
          account: account,
          conversation: c2,
          user: user2,
          name: 'conversation_resolved',
          value: 50,
          value_in_business_hours: 40,
          created_at: Time.current
        )
        create(
          :reporting_event,
          account: account,
          conversation: c1,
          user: user1,
          name: 'first_response',
          value: 20,
          value_in_business_hours: 10,
          created_at: Time.current
        )
        create(
          :reporting_event,
          account: account,
          conversation: c1,
          user: user1,
          name: 'reply_time',
          value: 30,
          value_in_business_hours: 15,
          created_at: Time.current
        )
        create(
          :reporting_event,
          account: account,
          conversation: c1,
          user: user1,
          name: 'reply_time',
          value: 40,
          value_in_business_hours: 25,
          created_at: Time.current
        )
      end

      context 'when business hours is disabled' do
        let(:business_hours) { false }

        it 'returns the correct agent stats' do
          report = builder.build

          expect(report).to match(
            [
              hash_including(
                id: user1.id,
                conversations_count: 1,
                replied_count: 1,
                open_count: 1,
                pending_count: 0,
                closed_count: 0,
                reopened_count: 0,
                current_workload: 1,
                avg_resolution_time: nil,
                avg_first_response_time: 20.0,
                avg_reply_time: 35.0,
                csat_score: nil
              ),
              hash_including(
                id: user2.id,
                conversations_count: 1,
                replied_count: 0,
                open_count: 0,
                pending_count: 0,
                closed_count: 1,
                reopened_count: 0,
                current_workload: 0,
                avg_resolution_time: 50.0,
                avg_first_response_time: nil,
                avg_reply_time: nil,
                csat_score: nil
              )
            ]
          )
        end

        it 'includes timing metrics with average, median and p90' do
          report = builder.build
          stats = report.find { |row| row[:id] == user1.id }

          expect(stats[:response_time]).to eq(average: 35.0, median: 35.0, p90: 39.0)
          expect(stats[:first_customer_response_time]).to eq(average: 20.0, median: 20.0, p90: 20.0)
        end
      end

      context 'when agent sends messages and notes' do
        let(:business_hours) { false }

        before do
          inbox = create(:inbox, account: account)
          conv = create(:conversation, account: account, inbox: inbox, assignee: user1, created_at: Time.current)
          create(:message, account: account, inbox: inbox, conversation: conv, message_type: :outgoing, sender: user1, private: false)
          create(:message, account: account, inbox: inbox, conversation: conv, message_type: :outgoing, sender: user1, private: true)
          create(:reporting_event, account: account, inbox: inbox, conversation: conv, user: user1, name: 'conversation_transferred', value: 0)
          create(:reporting_event, account: account, inbox: inbox, conversation: conv, user: user1, name: 'conversation_reassigned', value: 0)
        end

        it 'counts messages, notes, transfers, reassignments, and active hours' do
          report = builder.build
          stats = report.find { |row| row[:id] == user1.id }

          expect(stats[:messages_sent]).to eq(1)
          expect(stats[:internal_notes]).to eq(1)
          expect(stats[:transfers]).to eq(1)
          expect(stats[:reassignments]).to eq(1)
          expect(stats[:active_hours]).to be > 0.0
          expect(stats[:chats_per_active_hour]).to be > 0.0
        end
      end

      context 'when quality metrics are present' do
        let(:business_hours) { false }
        let(:inbox) { create(:inbox, account: account) }

        before do
          conv1 = create(:conversation, account: account, inbox: inbox, assignee: user1, status: :resolved, created_at: Time.current)
          msg1 = create(:message, account: account, inbox: inbox, conversation: conv1, message_type: :outgoing, sender: user1, private: false)
          create(
            :reporting_event,
            account: account, inbox: inbox, conversation: conv1,
            user: user1, name: 'conversation_resolved', value: 50, created_at: Time.current
          )

          create(
            :csat_survey_response,
            account: account, conversation: conv1, message: msg1,
            assigned_agent: user1, rating: 5, created_at: Time.current
          )

          if defined?(SlaPolicy) && defined?(AppliedSla)
            sla_policy = create(:sla_policy, account: account)
            create(:applied_sla, account: account, sla_policy: sla_policy, conversation: conv1, sla_status: :hit, created_at: Time.current)
          end
        end

        it 'calculates CSAT, positive/negative ratings, FCR, and SLA metrics' do
          report = builder.build
          stats = report.find { |row| row[:id] == user1.id }

          expect(stats[:csat_score]).to eq(100.0)
          expect(stats[:positive_ratings]).to eq(1)
          expect(stats[:negative_ratings]).to eq(0)
          expect(stats[:fcr_rate]).to eq(100.0)
          expect(stats[:sla_met]).to eq(1) if defined?(AppliedSla)
        end
      end

      context 'when business hours is enabled' do
        let(:business_hours) { true }

        it 'uses business hours values' do
          report = builder.build

          expect(report.pluck(:avg_first_response_time)).to eq([10.0, nil])
          expect(report.pluck(:avg_reply_time)).to eq([20.0, nil])
          expect(report.pluck(:avg_resolution_time)).to eq([nil, 40.0])
        end
      end
    end

    context 'when a conversation is reopened' do
      let(:business_hours) { false }

      before do
        conversation = create(:conversation, account: account, assignee: user1, created_at: Time.current)
        create(
          :reporting_event,
          account: account,
          conversation: conversation,
          user: user1,
          name: 'conversation_opened',
          value: 120,
          value_in_business_hours: 120,
          created_at: Time.current
        )
      end

      it 'counts the reopen against the assigned agent' do
        report = builder.build

        expect(report.find { |row| row[:id] == user1.id }[:reopened_count]).to eq(1)
      end
    end

    context 'when filtering by team' do
      let(:business_hours) { false }
      let(:team) { create(:team, account: account) }
      let(:params) do
        {
          business_hours: business_hours,
          since: 1.week.ago.beginning_of_day,
          until: Time.current.end_of_day,
          team_id: team.id
        }
      end

      before do
        create(:team_member, team: team, user: user1)
        create(:conversation, account: account, assignee: user1, team: team, created_at: Time.current)
        create(:conversation, account: account, assignee: user2, created_at: Time.current)
      end

      it 'only returns members of the team' do
        report = builder.build

        expect(report.pluck(:id)).to eq([user1.id])
        expect(report.first[:conversations_count]).to eq(1)
      end
    end

    context 'when filtering by agent' do
      let(:business_hours) { false }
      let(:params) do
        {
          business_hours: business_hours,
          since: 1.week.ago.beginning_of_day,
          until: Time.current.end_of_day,
          user_id: user2.id
        }
      end

      before do
        create(:conversation, account: account, assignee: user1, created_at: Time.current)
        create(:conversation, account: account, assignee: user2, created_at: Time.current)
      end

      it 'only returns the selected agent' do
        report = builder.build

        expect(report.pluck(:id)).to eq([user2.id])
        expect(report.first[:conversations_count]).to eq(1)
      end
    end

    context 'when there is no agent data' do
      let!(:new_user) { create(:user, account: account, role: :agent) }
      let(:business_hours) { false }

      it 'returns zero values' do
        report = builder.build

        expect(report).to include(
          hash_including(
            id: new_user.id,
            conversations_count: 0,
            replied_count: 0,
            open_count: 0,
            pending_count: 0,
            closed_count: 0,
            reopened_count: 0,
            current_workload: 0,
            avg_resolution_time: nil,
            avg_first_response_time: nil,
            avg_reply_time: nil,
            csat_score: nil,
            response_time: { average: nil, median: nil, p90: nil }
          )
        )
      end
    end
  end
end
