module Auth
  class SessionsController < ApplicationController
    include Authentication

    skip_before_action :authenticate_request!, only: [:register, :login]

    def register
      user = User.new(register_params)
      if user.save
        render json: auth_payload(user), status: :created
      else
        render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def login
      user = User.find_by(email: params[:email].to_s.downcase)
      if user&.authenticate(params[:password])
        render json: auth_payload(user)
      else
        render json: { error: "Invalid credentials" }, status: :unauthorized
      end
    end

    def me
      render json: { id: current_user.id, email: current_user.email, role: current_user.role }
    end

    private

    def register_params
      params.permit(:email, :password).merge(role: :player)
    end

    def auth_payload(user)
      {
        token: JsonWebToken.encode({ user_id: user.id }),
        user: {
          id: user.id,
          email: user.email,
          role: user.role
        }
      }
    end
  end
end
