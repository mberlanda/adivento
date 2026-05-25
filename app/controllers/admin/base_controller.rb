module Admin
  class BaseController < ApplicationController
    include Authentication
    include RoleAuthorization
  end
end
