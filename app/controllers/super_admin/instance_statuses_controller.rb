class SuperAdmin::InstanceStatusesController < SuperAdmin::ApplicationController
  def show
    @metrics = {}
    limcx_version
    sha
    platform_edition
    workspace_and_user_metrics
    postgres_status
    redis_metrics
    sidekiq_metrics
    storage_metrics
    channel_metrics
    instance_meta
  end

  def platform_edition
    @metrics['Platform edition'] = 'Limcx Unified Self-Hosted'
  end

  def instance_meta
    migrations_paths = ActiveRecord::Migrator.migrations_paths
    migrations_context = ActiveRecord::MigrationContext.new(migrations_paths)
    @metrics['Database Migrations'] = migrations_context.needs_migration? ? 'pending' : 'completed'
    @metrics['Ruby version'] = RUBY_VERSION
    @metrics['Rails version'] = Rails.version
    @metrics['Environment'] = Rails.env
  end

  def workspace_and_user_metrics
    @metrics.merge!(
      'Total workspaces' => Account.count,
      'Active workspaces' => Account.where(status: :active).count,
      'Suspended workspaces' => Account.where(status: :suspended).count,
      'Total users' => User.count,
      'Active users (last 30 days)' => User.where(last_sign_in_at: 30.days.ago..).count,
      'Online agents' => User.where(availability: 'online').count,
      'Total inboxes' => Inbox.count,
      'Total conversations' => Conversation.count
    )
  rescue StandardError => e
    @metrics['Workspace metrics'] = "error: #{e.message}"
  end

  def limcx_version
    @metrics['Limcx version'] = Chatwoot.config[:version]
  end

  def sha
    @metrics['Git SHA'] = GIT_HASH
  end

  def postgres_status
    @metrics['Postgres alive'] = ActiveRecord::Base.connection.active? ? 'true' : 'false'
    pool = ActiveRecord::Base.connection_pool
    @metrics['DB pool size'] = pool.size
    @metrics['DB connections in use'] = pool.connections.count(&:in_use?)
    @metrics['DB total connections'] = pool.connections.size
  rescue StandardError => e
    @metrics['Postgres alive'] = "error: #{e.message}"
  end

  def redis_metrics
    redis = Redis.new(Redis::Config.app)
    return unless redis.ping == 'PONG'

    redis_server = redis.info
    @metrics.merge!(
      'Redis alive' => 'true',
      'Redis version' => redis_server['redis_version'],
      'Redis number of connected clients' => redis_server['connected_clients'],
      "Redis 'maxclients' setting" => redis_server['maxclients'],
      'Redis memory used' => redis_server['used_memory_human'],
      'Redis memory peak' => redis_server['used_memory_peak_human'],
      'Redis total memory available' => redis_server['total_system_memory_human'],
      "Redis 'maxmemory' setting" => redis_server['maxmemory'],
      "Redis 'maxmemory_policy' setting" => redis_server['maxmemory_policy']
    )
  rescue Redis::CannotConnectError
    @metrics['Redis alive'] = 'false'
  rescue StandardError => e
    @metrics['Redis status'] = "error: #{e.message}"
  end

  def sidekiq_metrics
    if defined?(Sidekiq::Stats)
      stats = Sidekiq::Stats.new
      @metrics['Worker enqueued jobs'] = stats.enqueued
      @metrics['Worker processed jobs'] = stats.processed
      @metrics['Worker failed jobs'] = stats.failed
      @metrics['Worker retry count'] = stats.retry_size
      @metrics['Worker dead count'] = stats.dead_size
      @metrics['Worker scheduled jobs'] = stats.scheduled_size
      @metrics['Worker processes'] = stats.processes_size
    end
  rescue StandardError => e
    @metrics['Worker status'] = "unavailable: #{e.message}"
  end

  def storage_metrics
    if defined?(ActiveStorage::Blob)
      blob_count = ActiveStorage::Blob.count
      total_bytes = ActiveStorage::Blob.sum(:byte_size)
      @metrics['Storage files count'] = blob_count
      @metrics['Storage total size'] = ActiveSupport::NumberHelper.number_to_human_size(total_bytes)
      @metrics['Storage service'] = Rails.configuration.active_storage.service
    end
  rescue StandardError => e
    @metrics['Storage status'] = "unavailable: #{e.message}"
  end

  def channel_metrics
    inboxes_with_reauth = Inbox.includes(:channel).count do |inbox|
      inbox.channel.respond_to?(:reauthorization_required?) && inbox.channel.reauthorization_required?
    end
    @metrics['Inboxes requiring reauthorization'] = inboxes_with_reauth
  rescue StandardError => e
    @metrics['Channel status'] = "error: #{e.message}"
  end
end
