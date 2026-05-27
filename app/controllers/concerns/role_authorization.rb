module RoleAuthorization
  extend ActiveSupport::Concern

  private

  def require_permission!(permission_key)
    return if AuthorizationService.allowed?(user: current_user, permission_key: permission_key)

    render_forbidden
  end

  def require_any_role!(*roles)
    return if current_user && roles.map(&:to_s).include?(current_user.role)

    render_forbidden
  end

  def render_forbidden
    if request.format.html?
      redirect_to root_path, alert: 'Forbidden'
    else
      render json: { error: 'Forbidden' }, status: :forbidden
    end
  end
end
