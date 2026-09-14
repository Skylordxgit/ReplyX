class Api::V1::Accounts::AgentsController < Api::V1::Accounts::BaseController
  before_action :fetch_agent, except: [:create, :index, :bulk_create]
  before_action :check_authorization

  def index
    @agents = agents
  end

  def create
    builder = AgentBuilder.new(**agent_builder_params)
    @agent = builder.perform
  rescue AgentBuilder::LimitExceededError => e
    render_payment_required(e.message)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
  end

  def update
    @agent.update!(agent_params.slice(:name).compact)
    @agent.current_account_user.update!(agent_params.slice(*account_user_attributes).compact)
  end

  def reset_password
    if reset_password_params[:password].blank?
      render json: { error: I18n.t('errors.agents.password_required', default: 'Password is required') }, status: :unprocessable_entity
      return
    end

    forced = if reset_password_params.key?(:force_password_change)
               ActiveModel::Type::Boolean.new.cast(reset_password_params[:force_password_change])
             else
               true
             end

    @agent.admin_reset_password!(
      password: reset_password_params[:password],
      password_confirmation: reset_password_params[:password_confirmation] || reset_password_params[:password],
      force_password_change: forced,
      account: Current.account,
      actor: current_user
    )
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
  end

  def destroy
    @agent.current_account_user.destroy!
    delete_user_record(@agent)
    head :ok
  end

  def bulk_create
    emails = params[:emails]

    bulk_create_agents(emails)
    # This endpoint is used to bulk create agents during onboarding
    # onboarding_step key in present in Current account custom attributes, since this is a one time operation
    clear_onboarding_step
    head :ok
  rescue AgentBuilder::LimitExceededError => e
    render_payment_required(e.message)
  end

  private

  def check_authorization
    super(User)
  end

  def fetch_agent
    @agent = agents.find(params[:id])
  end

  def account_user_attributes
    [:role, :availability, :auto_offline, :active]
  end

  def allowed_agent_params
    [:name, :email, :role, :availability, :auto_offline, :active]
  end

  def agent_params
    params.require(:agent).permit(allowed_agent_params)
  end

  def new_agent_params
    params.require(:agent).permit(:email, :name, :role, :availability, :auto_offline, :password, :password_confirmation, :force_password_change)
  end

  def reset_password_params
    params.require(:agent).permit(:password, :password_confirmation, :force_password_change)
  rescue ActionController::ParameterMissing
    params.permit(:password, :password_confirmation, :force_password_change)
  end

  def agent_builder_params
    new_agent_params.to_h.symbolize_keys.merge(
      inviter: current_user,
      account: Current.account
    )
  end

  def agents
    @agents ||= Current.account.users.order_by_full_name.includes(:account_users, { avatar_attachment: [:blob] })
  end

  def bulk_create_agents(emails)
    email_limit_error = nil

    Current.account.with_lock do
      raise AgentBuilder::LimitExceededError if emails.count > available_agent_count

      emails.each do |email|
        create_agent_from_email(email)
      rescue CustomExceptions::Account::EmailLimitExceeded => e
        email_limit_error = e
      end
    end

    raise email_limit_error if email_limit_error
  end

  def create_agent_from_email(email)
    builder = AgentBuilder.new(
      email: email,
      name: email.split('@').first,
      inviter: current_user,
      account: Current.account
    )
    builder.perform
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.info "[Agent#bulk_create] ignoring email #{email}, errors: #{e.record.errors}"
  end

  def clear_onboarding_step
    Current.account.custom_attributes.delete('onboarding_step')
    Current.account.save!
  end

  def available_agent_count
    Current.account.usage_limits[:agents] - Current.account.account_users.count
  end

  def delete_user_record(agent)
    DeleteObjectJob.perform_later(agent) if agent.reload.account_users.blank?
  end
end

Api::V1::Accounts::AgentsController.prepend_mod_with('Api::V1::Accounts::AgentsController')
