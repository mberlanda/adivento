module Admin
  class BaseController < ApplicationController
    include Authentication
    include RoleAuthorization

    before_action :authenticate_request!
    before_action -> { require_permission!('backoffice.access') }
  end
end
