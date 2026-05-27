module Web
  class BaseController < ActionController::Base
    include Authentication
    include RoleAuthorization

    helper_method :current_user

    layout 'application'

    # Skip CSRF verification when the client authenticates via Bearer token.
    # Bearer tokens are already unforgeable (JWT-signed), so CSRF protection
    # is redundant and blocks API consumers of these endpoints.
    skip_before_action :verify_authenticity_token, if: :bearer_token_present?

    private

    def bearer_token_present?
      request.headers['Authorization'].to_s.start_with?('Bearer ')
    end
  end
end
