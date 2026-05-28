module Seeds
  class SyncRolePermissionsService
    def self.call!
      valid_roles = User.roles.keys
      invalid_roles = catalog_roles - valid_roles
      raise "Invalid roles in permission catalog: #{invalid_roles.join(', ')}" if invalid_roles.any?

      permissions_by_key = Permission.where(key: Catalogs::PermissionCatalog.keys).index_by(&:key)

      RolePermission.transaction do
        catalog_roles.each do |role|
          desired_permission_ids = Catalogs::PermissionCatalog::PERMISSIONS
                                   .select { |row| row.fetch(:default_roles, []).include?(role) }
                                   .map { |row| permissions_by_key.fetch(row.fetch(:key)).id }

          desired_permission_ids.each do |permission_id|
            RolePermission.find_or_create_by!(role_name: role, permission_id: permission_id)
          end

          RolePermission.where(role_name: role).where.not(permission_id: desired_permission_ids).delete_all
        end
      end
    end

    def self.catalog_roles
      User.roles.keys
    end
    private_class_method :catalog_roles
  end
end
