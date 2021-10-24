# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?
  # reset captcha code after each request for security
  after_action :reset_last_captcha_code!

  protect_from_forgery with: :exception

  rescue_from ActiveRecord::RecordNotFound, with: ->(exception) { render_error(404, exception) }
  rescue_from ActionController::RoutingError, with: ->(exception) { render_error(404, exception) }
  rescue_from ActionPolicy::Unauthorized, with: ->(exception) { render_error(404, exception) }

  # around_action :switch_locale
  # def switch_locale(&action)
  #  locale = params[:locale] || I18n.default_locale
  #  I18n.with_locale(locale, &action)
  # end

  protected

  def current_post
    @current_post ||= Post.find(params[:id])
  end

  def current_comment
    @current_comment ||= Comment.find(params[:id])
  end

  def current_channel
    @current_channel ||= Channel.find(params[:id])
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up) do |user_params|
      user_params.permit(:login, :password, :password_confirmation, :captcha)
    end
    devise_parameter_sanitizer.permit(:account_update) do |user_params|
      user_params.permit(:login, :password, :password_confirmation, :encrypted_password, :captcha, :avatar)
    end
  end

  def render_error(status, exception = nil)
    Rollbar.error(exception) if Rollbar.configuration.enabled
    render file: "#{Rails.root}/public/404.html", layout: false, status: :not_found if status == 404
  end
end
