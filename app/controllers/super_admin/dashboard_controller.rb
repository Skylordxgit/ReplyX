class SuperAdmin::DashboardController < SuperAdmin::ApplicationController
  include ActionView::Helpers::NumberHelper

  def index
    respond_to do |format|
      format.html
      format.json { render json: dashboard_stats }
    end
  end

  private

  def dashboard_stats
    Rails.cache.fetch('super_admin:dashboard_stats:v3', expires_in: 5.minutes) do
      account_metrics
        .merge(user_metrics)
        .merge(inbox_metrics)
        .merge(conversation_metrics)
        .merge(
          sidekiq: sidekiq_metrics,
          postgres: postgres_metrics,
          redis: redis_metrics,
          storage: storage_metrics,
          version: Chatwoot.config[:version],
          gitSha: GIT_HASH
        )
    end
  end

  def account_metrics
    {
      accountsCount: number_with_delimiter(Account.count),
      accountsActive: number_with_delimiter(Account.where(status: :active).count),
      accountsSuspended: number_with_delimiter(Account.where(status: :suspended).count)
    }
  end

  def user_metrics
    {
      usersCount: number_with_delimiter(User.count),
      usersActive30d: number_with_delimiter(User.where(last_sign_in_at: 30.days.ago..).count),
      usersOnline: number_with_delimiter(User.where(availability: 'online').count)
    }
  end

  def inbox_metrics
    {
      inboxesCount: number_with_delimiter(Inbox.count),
      inboxesReauthCount: count_inboxes_requiring_reauthorization
    }
  end

  def conversation_metrics
    {
      chartData: Conversation.unscoped.group_by_day(:created_at, range: 30.days.ago..2.seconds.ago).count.to_a,
      conversationsCount: number_with_delimiter(conversations_count_estimate),
      conversationsToday: number_with_delimiter(Conversation.where(created_at: Time.current.beginning_of_day..).count),
      conversationsOpen: number_with_delimiter(Conversation.where(status: :open).count),
      conversationsUnassigned: number_with_delimiter(Conversation.where(status: :open, assignee_id: nil).count)
    }
  end

  def sidekiq_metrics
    return {} unless defined?(Sidekiq::Stats)

    stats = Sidekiq::Stats.new
    {
      enqueued: stats.enqueued,
      processed: stats.processed,
      failed: stats.failed,
      retry_size: stats.retry_size,
      dead_size: stats.dead_size,
      processes: stats.processes_size
    }
  rescue StandardError => e
    { error: e.message }
  end

  def postgres_metrics
    pool = ActiveRecord::Base.connection_pool
    {
      alive: ActiveRecord::Base.connection.active?,
      pool_size: pool.size,
      connections_in_use: pool.connections.count(&:in_use?)
    }
  rescue StandardError => e
    { alive: false, error: e.message }
  end

  def redis_metrics
    redis = Redis.new(Redis::Config.app)
    return { alive: false } unless redis.ping == 'PONG'

    info = redis.info
    {
      alive: true,
      version: info['redis_version'],
      used_memory: info['used_memory_human'],
      peak_memory: info['used_memory_peak_human'],
      connected_clients: info['connected_clients']
    }
  rescue StandardError => e
    { alive: false, error: e.message }
  end

  def storage_metrics
    return {} unless defined?(ActiveStorage::Blob)

    {
      count: ActiveStorage::Blob.count,
      total_size: ActiveSupport::NumberHelper.number_to_human_size(ActiveStorage::Blob.sum(:byte_size)),
      service: Rails.configuration.active_storage.service
    }
  rescue StandardError => e
    { error: e.message }
  end

  def count_inboxes_requiring_reauthorization
    Inbox.includes(:channel).count do |inbox|
      inbox.channel.respond_to?(:reauthorization_required?) && inbox.channel.reauthorization_required?
    end
  rescue StandardError
    0
  end

  def conversations_count_estimate
    estimate = ActiveRecord::Base.connection.select_value(
      "SELECT reltuples::bigint FROM pg_class WHERE relname = 'conversations'"
    ).to_i
    estimate.negative? ? Conversation.count : estimate
  end
end
