module Web
  class BaseController < ActionController::Base
    include Authentication
    include RoleAuthorization

    helper_method :current_user

    layout "application"
  end
end
