module Web
  class SessionsController < ActionController::Base
    layout "application"

    def new; end

    def create
      user = User.find_by(email: params[:email].to_s.downcase)
      if user&.authenticate(params[:password])
        session[:user_id] = user.id
        redirect_to root_path, notice: "Signed in"
      else
        flash.now[:alert] = "Invalid credentials"
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      session.delete(:user_id)
      redirect_to root_path, notice: "Signed out"
    end
  end
end
