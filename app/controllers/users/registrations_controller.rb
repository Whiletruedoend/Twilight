# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
#  before_action :configure_sign_up_params, only: [:create]
#  before_action :configure_account_update_params, only: [:update]

  # GET /resource/sign_up
  #def new
    #super
  #end

  # POST /resource
  def create
    if valid_captcha?(params[:user][:captcha])
      super
      Tag.all.each { |tag| ItemTag.create!(item: current_user, tag: tag, enabled: tag.enabled_by_default) }
      SendAuthorMessage.call(params[:user][:login]) if Rails.configuration.credentials[:telegram][:reg_notify] # todo: more platform support
    else
      redirect_to(sign_up_url)
    end
  end

  # GET /resource/edit
  #def edit
  #  super
  #end

  # PUT /resource
  def update
    if params.has_key?(:tags)
      params[:tags].each do |tag|
        item_tag = ItemTag.where(item: current_user, tag_id: tag[0]).first
        item_tag.update(enabled: tag[1]) if item_tag.present?
      end
    end
    super
  end

  # DELETE /resource
  def destroy
    post = Post.where(user: current_user)
    ItemTag.where(item: post).delete_all
    ItemTag.where(item: current_user).delete_all
    PlatformPost.where(post_id: post).delete_all
    post.delete_all
    super
  end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  #def cancel
    #super
  #end

  #protected

  # If you have extra params to permit, append them to the sanitizer.
  #  def configure_sign_up_params
  #   devise_parameter_sanitizer.permit(:sign_up, keys: [:captcha])
  # end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_account_update_params
  #  devise_parameter_sanitizer.permit(:account_update, keys: [:captcha])
  # end

  # The path used after sign up.
  # def after_sign_up_path_for(resource)
  #   super(resource)
  # end

  # The path used after sign up for inactive accounts.
  # def after_inactive_sign_up_path_for(resource)
  #   super(resource)
  # end
end
