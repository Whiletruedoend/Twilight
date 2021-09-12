# frozen_string_literal: true

class InviteCodesController < ApplicationController
  before_action :check_admin

  def check_admin
    redirect_to root_path unless current_user.is_admin
  end

  def new
    return redirect_to sign_in_path if current_user.nil?

    @invite_code = InviteCode.new
  end

  def create
    return redirect_to sign_in_path if current_user.nil?

    @invite_code = InviteCode.new

    @invite_code.code = SecureRandom.uuid

    @invite_code.user = current_user
    @invite_code.is_enabled = params.dig('invite_code', 'is_enabled') || false
    is_multiple_use = params.dig('invite_code', 'is_multiple_use') == '1'
    @invite_code.is_single_use = !is_multiple_use
    @invite_code.usages = 0
    @invite_code.max_usages = params.dig('invite_code', 'max_usages') || 1
    @invite_code.expires_at =
      if params.dig('invite_code',
                    'expires_at') == ''
        nil
      else
        params.dig('invite_code', 'expires_at')
      end

    if @invite_code.save
      redirect_to edit_user_path
    else
      render :new
    end
  end
end
