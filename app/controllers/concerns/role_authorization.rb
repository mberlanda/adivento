module RoleAuthorization
  extend ActiveSupport::Concern

  private

  def require_any_role!(*roles)
    return if current_user && roles.map(&:to_s).include?(current_user.role)

    render json: { error: "Forbidden" }, status: :forbidden
  end
end
