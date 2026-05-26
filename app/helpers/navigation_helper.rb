module NavigationHelper
  def current_nav_user
    return @current_nav_user if defined?(@current_nav_user)

    @current_nav_user = User.find_by(id: session[:user_id]) if session[:user_id].present?
  end

  def navigation_actions
    @navigation_actions ||= AvailableActionsService.call(user: current_nav_user)
                                                 .select { |action| action[:surface] == "navigation" }
  end

  def nav_action_path(action_key)
    navigation_actions.find { |action| action[:key] == action_key }&.dig(:path)
  end

  def nav_action_available?(action_key)
    nav_action_path(action_key).present?
  end

  def backoffice_visible_in_nav?
    nav_action_available?("navigation.backoffice")
  end
end
