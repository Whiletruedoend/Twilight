class TagsController < ApplicationController

  before_action :authenticate_user!
  before_action :check_admin

  def check_admin
    redirect_to root_path unless current_user.is_admin
  end

  def destroy
    tag = Tag.find_by_name(params[:tag][:name])
    if tag.present?
      ItemTag.where(tag: tag).delete_all
      tag.delete
    end
    redirect_to manage_tag_path
  end

  def new
    @tag = Tag.new
  end

  def create
    @tag = Tag.new
    @tag.name = tags_params[:tag][:name]
    @tag.save!
    if @tag.save
      User.all.each { |usr| ItemTag.create!(item: usr, tag_id: @tag.id, enabled: tags_params[:tag][:enabled]) }
      redirect_to manage_tag_path
    else
      render :manage_tag_path
    end
  end

  private
  def tags_params
    params.permit(:authenticity_token, :commit, :tag => [:name, :enabled])
  end
end
