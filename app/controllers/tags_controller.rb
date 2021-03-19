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
    @tag = Tag.new(tags_params[:tag])
    @tag.save!
    if @tag.save
      User.all.each { |usr| ItemTag.create!(item: usr, tag_id: @tag.id, enabled: tags_params[:tag][:enabled_by_default]) }
      Post.all.each { |post| ItemTag.create!(item: post, tag_id: @tag.id, enabled: false) }
      redirect_to manage_tag_path
    else
      render :manage_tag_path
    end
  end

  def rename
    @tag = Tag.find_by_name(rename_params[:name])
    @tag.update(name: rename_params[:new_name]) if @tag.present?
    redirect_to manage_tag_path
  end

  def update
    tags_params[:tags].each{ |tag| Tag.find(tag[0]).update(enabled_by_default: tag[1])}
    redirect_to manage_tag_path
  end

  private
  def rename_params
    params.permit(:authenticity_token, :commit, :name, :new_name)
  end
  def tags_params
    params.permit(:authenticity_token, :commit, :tags => {}, :tag => [:name, :enabled_by_default])
  end
end
