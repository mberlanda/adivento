module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_request!
  end

  private

  def authenticate_request!
    token = request.headers["Authorization"].to_s.split.last
    payload = JsonWebToken.decode(token)
    @current_user = User.find_by(id: payload["user_id"])
    render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
  rescue JWT::DecodeError, JWT::ExpiredSignature
    render json: { error: "Unauthorized" }, status: :unauthorized
  end

  def current_user
    @current_user
  end
end
