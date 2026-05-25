module Backoffice
  class PermissionsController < BaseController
    before_action -> { require_permission!("permission.manage") }

    def index
      @permissions = Permission.order(:key)
      @roles = User.roles.keys
      @role_permissions = RolePermission.includes(:permission).all.group_by(&:role_name)
    end

    def update
      permission = Permission.find(params[:id])
      role_name = params[:role_name].to_s
      enabled = ActiveModel::Type::Boolean.new.cast(params[:enabled])
      reason = params[:reason].to_s

      if reason.blank?
        return redirect_to backoffice_permissions_path, alert: "Reason is required"
      end

      if enabled
        RolePermission.find_or_create_by!(role_name: role_name, permission: permission)
      else
        RolePermission.where(role_name: role_name, permission: permission).destroy_all
      end

      AuditEvent.create!(
        actor: current_user,
        action: "permission.role_mapping_changed",
        target_type: "Permission",
        target_id: permission.id,
        reason: reason,
        metadata: { role_name: role_name, enabled: enabled }
      )

      redirect_to backoffice_permissions_path, notice: "Role permission updated"
    end
  end
end
