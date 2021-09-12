# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    # before_action :configure_sign_in_params, only: [:create]

    # GET /resource/sign_in

    # POST /resource/sign_in
    def create
      if valid_captcha?(params[:user][:captcha])
        super
      else
        redirect_to sign_in_url
      end
    end

    # DELETE /resource/sign_out

    # protected

    # If you have extra params to permit, append them to the sanitizer.
    # def configure_sign_in_params
    #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
    # end
  end
end
