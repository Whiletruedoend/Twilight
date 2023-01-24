# frozen_string_literal: true

class CategoriesController < ApplicationController
  before_action :check_admin

  def check_admin
    redirect_to root_path unless current_user.is_admin
  end

  def update
    return redirect_to sign_in_path if current_user.nil?
    if params[:commit] == I18n.t("tags.update")
      @category = Category.find(params[:category][:id].to_i)

      @category.name = params[:category][:name] if params[:category][:name].present?
      @category.color = params[:category][:color] if params[:category][:color].present?
      @category.sort = params[:category][:sort] if params[:category][:sort].present?

      if @category.save
        redirect_to edit_user_path
      else
        render :new
      end
    else # Delete
      @category = Category.find_by(id: params[:category][:id].to_i)
      @category.delete if @category.user == current_user
      redirect_to edit_user_path
    end
  end

  def new
    return redirect_to sign_in_path if current_user.nil?

    @category = Category.new
  end

  def create
    return redirect_to sign_in_path if current_user.nil?

    @category = Category.new

    @category.user = current_user
    @category.name = params[:category][:name]
    @category.color = params[:category][:color]
    @category.sort = params[:category][:sort]

    if @category.save
      redirect_to edit_user_path
    else
      render :new
    end
  end
end
