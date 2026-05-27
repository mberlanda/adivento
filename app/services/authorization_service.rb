class AuthorizationService
  def self.allowed?(user:, permission_key:)
    return false if user.nil?

    permission = Permission.find_by(key: permission_key, active: true)
    return false unless permission

    grant = UserGrant.active_now.where(user: user, permission: permission).order(created_at: :desc).first
    return grant.allow unless grant.nil?

    RolePermission.exists?(role_name: user.role, permission: permission)
  end
end
