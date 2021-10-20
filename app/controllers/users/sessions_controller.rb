# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    # before_action :configure_sign_in_params, only: [:create]

    # GET /resource/sign_in

    # POST /resource/sign_in
    def create
      if valid_captcha?(sessions_params[:user][:captcha])
        super
      else
        redirect_to sign_in_url
      end
    end

    protected

    def sessions_params
      params.permit(:authenticity_token,
                    :commit,
                    user: %i[login
                             password
                             code
                             captcha
                             remember_me])
    end

    # DELETE /resource/sign_out

    # protected

    # If you have extra params to permit, append them to the sanitizer.
    # def configure_sign_in_params
    #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
    # end
  end
end
