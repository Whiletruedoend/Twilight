class ApplicationController < ActionController::Base
  #around_action :switch_locale

  #def switch_locale(&action)
  #  locale = params[:locale] || I18n.default_locale
  #  I18n.with_locale(locale, &action)
  #end

  protect_from_forgery with: :exception
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up) do |user_params|
      user_params.permit(:login, :password, :password_confirmation, :locale)
    end
    devise_parameter_sanitizer.permit(:account_update) do |user_params|
      user_params.permit(:login, :password, :password_confirmation, :locale, :current_password)
    end
  end
end