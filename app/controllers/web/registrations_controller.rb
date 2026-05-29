module Web
  class RegistrationsController < ActionController::Base
    layout 'application'

    def new
      @user = User.new
    end

    def create
      @user = User.new(email: params[:email], password: params[:password], role: :player)
      if @user.save
        session[:user_id] = @user.id
        redirect_to root_path, notice: 'Welcome to Adivento! Request tokens from your profile to start betting.'
      else
        flash.now[:alert] = @user.errors.full_messages.to_sentence
        render :new, status: :unprocessable_content
      end
    end
  end
end
