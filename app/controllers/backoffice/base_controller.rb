module Backoffice
  class BaseController < ActionController::Base
    include Authentication
    include RoleAuthorization

    helper_method :current_user

    before_action :authenticate_request!
    before_action -> { require_permission!("backoffice.access") }

    layout "backoffice"
  end
end
