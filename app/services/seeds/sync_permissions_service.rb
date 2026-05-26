require_dependency Rails.root.join("app/domain/catalogs/permission_catalog").to_s

module Seeds
  class SyncPermissionsService
    def self.call!
      desired_keys = Domain::Catalogs::PermissionCatalog.keys

      Permission.transaction do
        Domain::Catalogs::PermissionCatalog::PERMISSIONS.each do |row|
          permission = Permission.find_or_initialize_by(key: row.fetch(:key))
          permission.assign_attributes(
            description: row.fetch(:description),
            active: row.fetch(:active, true)
          )
          permission.save! if permission.changed?
        end

        Permission.where.not(key: desired_keys).update_all(active: false, updated_at: Time.current)
      end
    end
  end
end
