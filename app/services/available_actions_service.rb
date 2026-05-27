require_dependency Rails.root.join('app/domain/catalogs/action_catalog').to_s

class AvailableActionsService
  def self.call(user:)
    ::Domain::Catalogs::ActionCatalog::ACTIONS.each_with_object([]) do |action, available|
      next unless audience_matches?(action.fetch(:audience), user)
      next unless permission_matches?(action[:permission_key], user)

      available << {
        key: action.fetch(:key),
        surface: action.fetch(:surface),
        path: action.fetch(:path),
        method: action.fetch(:method)
      }
    end
  end

  def self.audience_matches?(audience, user)
    case audience
    when 'all'
      true
    when 'guest'
      user.nil?
    when 'signed_in'
      user.present?
    else
      false
    end
  end
  private_class_method :audience_matches?

  def self.permission_matches?(permission_key, user)
    return true if permission_key.blank?
    return false if user.nil?

    AuthorizationService.allowed?(user: user, permission_key: permission_key)
  end
  private_class_method :permission_matches?
end
