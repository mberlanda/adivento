module Backoffice
  class GrantsController < BaseController
    before_action -> { require_permission!("grant.manage") }

    def index
      @users = User.order(:email)
      @permissions = Permission.where(active: true).order(:key)
      @grants = UserGrant.includes(:user, :permission, :granted_by).order(created_at: :desc).limit(100)
    end

    def create
      user = User.find(params[:user_id])
      permission = Permission.find(params[:permission_id])
      allow = ActiveModel::Type::Boolean.new.cast(params[:allow])
      reason = params[:reason].to_s

      if reason.blank?
        return redirect_to backoffice_grants_path, alert: "Reason is required"
      end

      UserGrant.create!(
        user: user,
        permission: permission,
        allow: allow,
        reason: reason,
        granted_by: current_user
      )

      AuditEvent.create!(
        actor: current_user,
        action: "permission.user_grant_changed",
        target_type: "User",
        target_id: user.id,
        reason: reason,
        metadata: { permission_key: permission.key, allow: allow }
      )

      redirect_to backoffice_grants_path, notice: "Grant created"
    end
  end
end
