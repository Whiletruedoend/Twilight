# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
#  before_action :configure_sign_up_params, only: [:create]
#  before_action :configure_account_update_params, only: [:update]
  before_action :configure_permitted_parameters, if: :devise_controller?

  # GET /resource/sign_up
  #def new
    #super
  #end

  # POST /resource
  def create
    return redirect_to(sign_up_url, :alert => ["Invalid captcha!"]) unless valid_captcha?(params[:user][:captcha])
    return redirect_to(sign_up_url, :alert => ["Invalid invite code!"]) unless validate_code(params[:user][:code])
    super
    if current_user.present?
      if Rails.configuration.credentials[:invite_codes_register_only]
        options = current_user.options
        options.merge!(invite_code: params[:user][:code])
        current_user.update!(options: options)
      end
      Tag.all.each { |tag| ItemTag.create!(item: current_user, tag: tag, enabled: tag.enabled_by_default) }
      #SendAuthorMessage.call(params[:user][:login]) if Rails.configuration.credentials[:telegram][:reg_notify] # todo: more platform support
    end
  end

  def validate_code(code)
    return true unless Rails.configuration.credentials[:invite_codes_register_only]
    code = InviteCode.find_by_code(code)

    return false if code.nil? || !code.is_enabled

    if code.expires_at.present? && (DateTime.now > code.expires_at)
      code.is_enabled = false
      code.save!
      return false
    end

    if code.is_single_use
      code.usages += 1
      code.is_enabled = false
    else
      if (code.usages < code.max_usages) || (code.max_usages == 0)
        code.usages += 1
        code.is_enabled = false if (code.usages >= code.max_usages) && (code.max_usages != 0)
      else
        return false
      end
    end

    code.save!
    true
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
    if params.dig(:user,:options).present? && current_user.present?
      options = current_user.options
      new_options = params[:user][:options]
      new_options.each { |k,v| options.merge!(k=>v) if v != options[k] }
      current_user.options = options
      current_user.save! if current_user.valid?
    end
    super
  end

  # DELETE /resource
  def destroy
    posts = Post.where(user: current_user)
    ItemTag.where(item: posts).delete_all
    ItemTag.where(item: current_user).delete_all
    Channel.where(user: current_user).delete_all
    PlatformPost.where(post: posts).delete_all
    posts.each { |post| post.get_content_attachments&.delete_all }
    posts.delete_all
    Content.where(post: posts).delete_all
    Content.where(user: current_user).delete_all
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

  protected

  # If you have extra params to permit, append them to the sanitizer.
  #  def configure_sign_up_params
  #   devise_parameter_sanitizer.permit(:sign_up, keys: [:captcha])
  # end

  def configure_permitted_parameters
    attributes = [:avatar, :options => {}]
    devise_parameter_sanitizer.permit(:sign_up, keys: attributes)
    devise_parameter_sanitizer.permit(:account_update, keys: attributes)
  end

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
