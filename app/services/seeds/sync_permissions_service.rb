module Seeds
  class SyncPermissionsService
    def self.call!
      desired_keys = Catalogs::PermissionCatalog.keys

      Permission.transaction do
        Catalogs::PermissionCatalog::PERMISSIONS.each do |row|
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
