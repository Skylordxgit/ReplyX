# Helper service to apply common report conversation filters (inbox, channel, status, priority, team).
class Reports::ConversationFilterApplicator
  CONV_KEYS = %i[inbox_id status priority team_id].freeze

  def self.apply_to_conversations(scope, params)
    s = scope
    CONV_KEYS.each do |key|
      s = s.where(key => params[key]) if params[key].present?
    end
    s = s.where(assignee_id: params[:user_id]) if params[:user_id].present?
    s = s.joins(:inbox).where(inboxes: { channel_type: params[:channel_type] }) if params[:channel_type].present?
    s
  end

  def self.apply_to_joined(scope, params)
    s = scope
    CONV_KEYS.each do |key|
      s = s.joins(:conversation).where(conversations: { key => params[key] }) if params[key].present?
    end
    s = s.joins(conversation: :inbox).where(inboxes: { channel_type: params[:channel_type] }) if params[:channel_type].present?
    s
  end
end
