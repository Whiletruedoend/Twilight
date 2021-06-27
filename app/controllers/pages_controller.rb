class PagesController < ApplicationController
  before_action :check_admin, only: [:full_users_list, :full_invite_codes_list]

  def check_admin
    redirect_to root_path unless current_user.is_admin
  end

  def full_users_list
  end

  def full_invite_codes_list
  end
end