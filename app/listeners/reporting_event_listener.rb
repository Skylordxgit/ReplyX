class ReportingEventListener < BaseListener
  include ReportingEventHelper

  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]
    event_end_time = event.timestamp
    time_to_resolve = event_end_time.to_i - conversation.created_at.to_i

    reporting_event = ReportingEvent.new(
      name: 'conversation_resolved',
      value: time_to_resolve,
      value_in_business_hours: business_hours(conversation.inbox, conversation.created_at, event_end_time),
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      user_id: conversation.assignee_id,
      conversation_id: conversation.id,
      event_start_time: conversation.created_at,
      event_end_time: event_end_time
    )

    create_bot_resolved_event(conversation, reporting_event)
    reporting_event.save!
    safe_rollup(reporting_event)
  end

  def first_reply_created(event)
    message = extract_message_and_account(event)[0]
    conversation = message.conversation
    first_response_time = message.created_at.to_i - last_non_human_activity(conversation).to_i

    reporting_event = ReportingEvent.new(
      name: 'first_response',
      value: first_response_time,
      value_in_business_hours: business_hours(conversation.inbox, last_non_human_activity(conversation), message.created_at),
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      user_id: message.sender_id,
      conversation_id: conversation.id,
      event_start_time: last_non_human_activity(conversation),
      event_end_time: message.created_at
    )

    reporting_event.save!
    safe_rollup(reporting_event)
  end

  def reply_created(event)
    message = extract_message_and_account(event)[0]
    conversation = message.conversation
    waiting_since = event.data[:waiting_since]
    return if waiting_since.blank?

    reply_time = message.created_at.to_i - waiting_since.to_i

    reporting_event = ReportingEvent.new(
      name: 'reply_time',
      value: reply_time,
      value_in_business_hours: business_hours(conversation.inbox, waiting_since, message.created_at),
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      user_id: conversation.assignee_id,
      conversation_id: conversation.id,
      event_start_time: waiting_since,
      event_end_time: message.created_at
    )
    reporting_event.save!
    safe_rollup(reporting_event)
  end

  def conversation_bot_handoff(event)
    conversation = extract_conversation_and_account(event)[0]
    event_end_time = event.timestamp
    return if ReportingEvent.find_by(conversation_id: conversation.id, name: 'conversation_bot_handoff').present?

    reporting_event = ReportingEvent.new(
      name: 'conversation_bot_handoff',
      value: event_end_time.to_i - conversation.created_at.to_i,
      value_in_business_hours: business_hours(conversation.inbox, conversation.created_at, event_end_time),
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      user_id: conversation.assignee_id,
      conversation_id: conversation.id,
      event_start_time: conversation.created_at,
      event_end_time: event_end_time
    )
    reporting_event.save!
    safe_rollup(reporting_event)
  end

  def conversation_opened(event)
    conversation = extract_conversation_and_account(event)[0]
    event_end_time = event.timestamp

    last_resolved_event = ReportingEvent.where(conversation_id: conversation.id, name: 'conversation_resolved')
                                        .where('event_end_time <= ?', event_end_time).order(event_end_time: :desc).first

    if last_resolved_event
      time_since_resolved = event_end_time.to_i - last_resolved_event.event_end_time.to_i
      business_hours_value = business_hours(conversation.inbox, last_resolved_event.event_end_time, event_end_time)
      start_time = last_resolved_event.event_end_time
    else
      time_since_resolved = 0
      business_hours_value = 0
      start_time = conversation.created_at
    end

    create_conversation_opened_event(conversation, time_since_resolved, business_hours_value, start_time, event_end_time)
  end

  def assignee_changed(event)
    conversation = extract_conversation_and_account(event)[0]
    assignee_id = conversation.assignee_id
    return if assignee_id.blank?

    create_assignment_events(conversation, assignee_id, event)
  end

  def team_changed(event)
    conversation = extract_conversation_and_account(event)[0]
    return if conversation.blank?

    user_id = actor_user_id(event, conversation)
    create_transferred_event(conversation, user_id, event.timestamp) if user_id.present?
  end

  private

  def actor_user_id(event, conversation)
    event.data[:performed_by]&.id ||
      Current.user&.id ||
      conversation.assignee_id ||
      event.data.dig(:changed_attributes, :assignee_id, 0)
  end

  def safe_rollup(reporting_event)
    ReportingEvents::RollupService.perform(reporting_event)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: reporting_event.account).capture_exception
  end
end
