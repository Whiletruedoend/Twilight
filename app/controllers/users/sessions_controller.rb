# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    # before_action :configure_sign_in_params, only: [:create]
    prepend_before_action :captcha_valid, only: [:create]

    # GET /resource/sign_in

    def set_tags
      set_meta_tags(title: 'Sign in',
                    description: 'Sign in to view posts and manage preferences',
                    keywords: 'Twilight, Notes, signin')
    end

    protected

    def captcha_valid
      if valid_captcha?(sessions_params[:user][:captcha])
        true
      else
        set_flash_message :alert, :wrong_captcha
        redirect_to sign_in_url
      end
    end

    def sessions_params
      params.permit(:authenticity_token,
                    :commit,
                    user: [:login,
                            :password,
                            :code,
                            :captcha,
                            :remember_me,
                          ])
    end

    # DELETE /resource/sign_out

    # protected

    # If you have extra params to permit, append them to the sanitizer.
    # def configure_sign_in_params
    #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
    # end
  end
end
