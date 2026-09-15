class Api::V1::Accounts::CannedResponsesController < Api::V1::Accounts::BaseController
  before_action :fetch_canned_response, only: [:update, :destroy]
  before_action :authorize_canned_response

  def index
    render json: serialize(canned_responses)
  end

  def create
    @canned_response = Current.account.canned_responses.new(creator: Current.user)
    @canned_response.transaction do
      assign_attributes
      @canned_response.save!
    end
    render json: serialize(@canned_response)
  end

  def update
    @canned_response.transaction do
      assign_attributes
      @canned_response.save!
    end
    render json: serialize(@canned_response)
  end

  def destroy
    @canned_response.destroy!
    head :ok
  end

  private

  def fetch_canned_response
    @canned_response = policy_scope(Current.account.canned_responses).find(params[:id])
  end

  def authorize_canned_response
    authorize(@canned_response || CannedResponse)
  end

  def canned_response_params
    params.require(:canned_response).permit(:short_code, :content, :access_scope, allowed_team_ids: [], allowed_user_ids: [])
  end

  def assign_attributes
    attributes = canned_response_params
    @canned_response.creator ||= Current.user
    @canned_response.assign_attributes(attributes.except(:allowed_team_ids, :allowed_user_ids))

    if @canned_response.specific_teams?
      @canned_response.allowed_teams = Current.account.teams.find(attributes.fetch(:allowed_team_ids, @canned_response.allowed_team_ids))
      @canned_response.allowed_users = []
    elsif @canned_response.specific_users?
      @canned_response.allowed_users = Current.account.users.find(attributes.fetch(:allowed_user_ids, @canned_response.allowed_user_ids))
      @canned_response.allowed_teams = []
    else
      @canned_response.allowed_teams = []
      @canned_response.allowed_users = []
    end
  end

  def canned_responses
    responses = policy_scope(Current.account.canned_responses).includes(:allowed_teams, :allowed_users)

    if params[:search]
      search = params[:search].delete("\0")
      responses.where('short_code ILIKE :search OR content ILIKE :search', search: "%#{search}%")
               .order_by_search(search)

    else
      responses
    end
  end

  def serialize(records)
    records.as_json(
      methods: [:allowed_team_ids, :allowed_user_ids],
      include: {
        allowed_teams: { only: [:id, :name] },
        allowed_users: { only: [:id, :name, :email] }
      }
    )
  end
end
