module ReportingEventHelper
  def business_hours(inbox, from, to)
    return 0 unless inbox.working_hours_enabled?

    inbox_working_hours = configure_working_hours(inbox.working_hours)
    return 0 if inbox_working_hours.blank?

    WorkingHours::Config.working_hours = inbox_working_hours
    WorkingHours::Config.time_zone = inbox.timezone

    from_in_inbox_timezone = from.in_time_zone(inbox.timezone).to_time
    to_in_inbox_timezone = to.in_time_zone(inbox.timezone).to_time
    from_in_inbox_timezone.working_time_until(to_in_inbox_timezone)
  end

  def last_non_human_activity(conversation)
    event = ReportingEvent.where(
      conversation_id: conversation.id,
      name: %w[conversation_bot_handoff conversation_opened]
    ).order(event_end_time: :desc).first

    return event.event_end_time if event&.event_end_time

    bot_event = ReportingEvent.where(conversation_id: conversation.id, name: 'conversation_bot_resolved').last
    return bot_event.event_end_time if bot_event&.event_end_time

    conversation.created_at
  end

  def create_assignment_events(conversation, assignee_id, event)
    ReportingEvent.create!(
      name: 'conversation_assigned',
      value: event.timestamp.to_i - conversation.created_at.to_i,
      value_in_business_hours: business_hours(conversation.inbox, conversation.created_at, event.timestamp),
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      user_id: assignee_id,
      conversation_id: conversation.id,
      event_start_time: conversation.created_at,
      event_end_time: event.timestamp
    )

    create_reassigned_event_if_needed(conversation, assignee_id, event)
  end

  def create_reassigned_event_if_needed(conversation, assignee_id, event)
    changed_attrs = event.data[:changed_attributes] || {}
    prev_id = changed_attrs[:assignee_id]&.first || changed_attrs['assignee_id']&.first
    return if prev_id.blank? || prev_id == assignee_id

    create_instant_event('conversation_reassigned', conversation, assignee_id, event.timestamp)
  end

  def create_transferred_event(conversation, user_id, event_time)
    create_instant_event('conversation_transferred', conversation, user_id, event_time)
  end

  def create_instant_event(name, conversation, user_id, event_time)
    ReportingEvent.create!(
      name: name, value: 0, value_in_business_hours: 0,
      account_id: conversation.account_id, inbox_id: conversation.inbox_id,
      user_id: user_id, conversation_id: conversation.id,
      event_start_time: event_time, event_end_time: event_time
    )
  end

  def create_conversation_opened_event(conversation, time_since_resolved, business_hours_value, start_time, event_end_time)
    ReportingEvent.create!(
      name: 'conversation_opened',
      value: time_since_resolved,
      value_in_business_hours: business_hours_value,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      user_id: conversation.assignee_id,
      conversation_id: conversation.id,
      event_start_time: start_time,
      event_end_time: event_end_time
    )
  end

  def create_bot_resolved_event(conversation, reporting_event)
    return unless conversation.inbox.active_bot?
    return if conversation.messages.exists?(message_type: :outgoing, sender_type: 'User')

    bot_resolved_event = reporting_event.dup
    bot_resolved_event.name = 'conversation_bot_resolved'
    bot_resolved_event.save!
    safe_rollup(bot_resolved_event)
  end

  private

  def configure_working_hours(working_hours)
    working_hours.each_with_object({}) do |working_hour, object|
      object[day(working_hour.day_of_week)] = working_hour_range(working_hour) unless working_hour.closed_all_day?
    end
  end

  def day(day_of_week)
    { 0 => :sun, 1 => :mon, 2 => :tue, 3 => :wed, 4 => :thu, 5 => :fri, 6 => :sat }[day_of_week]
  end

  def working_hour_range(working_hour)
    { format_time(working_hour.open_hour, working_hour.open_minutes) => format_time(working_hour.close_hour, working_hour.close_minutes) }
  end

  def format_time(hour, minute)
    format('%<hour>02d:%<minute>02d', hour: hour, minute: minute)
  end
end
