module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_request!
  end

  private

  def authenticate_request!
    @current_user = find_authenticated_user
    return if @current_user

    render_unauthorized
  rescue JWT::DecodeError, JWT::ExpiredSignature
    render_unauthorized
  end

  def current_user
    @current_user
  end

  def find_authenticated_user
    bearer = request.headers['Authorization'].to_s.split.last
    if bearer.present?
      payload = JsonWebToken.decode(bearer)
      return User.find_by(id: payload['user_id'])
    end

    User.find_by(id: session[:user_id]) if respond_to?(:session)
  end

  def render_unauthorized
    if browser_page_request?
      redirect_to signin_path, alert: 'Please sign in'
    else
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  def browser_page_request?
    request.format.html? && request.path.start_with?('/web', '/backoffice', '/signin', '/signout',
                                                     '/') && !request.path.start_with?('/auth', '/admin', '/wallet',
                                                                                       '/faucet_requests', '/markets', '/sse')
  end
end
