# frozen_string_literal: true

class TagsController < ApplicationController
  before_action :authenticate_user!
  before_action :check_admin

  def check_admin
    redirect_to root_path unless current_user.is_admin
  end

  def update
    # tags_params[:tags].each{ |tag| Tag.find(tag[0]).update(enabled_by_default: tag[1])}
    if params[:commit] == 'Update'
      @tag = Tag.find(params[:tag][:id].to_i)

      @tag.name = params[:tag][:name] if params[:tag][:name].present?
      @tag.enabled_by_default = params.dig('tag', @tag.id.to_s) if params.dig('tag', @tag.id.to_s).present?
      @tag.sort = params[:tag][:sort] if params[:tag][:sort].present?

      if @tag.save
        redirect_to edit_user_path
      else
        render :new
      end
    else # Delete
      @tag = Tag.find_by(id: params[:tag][:id].to_i)
      if @tag.present?
        ItemTag.where(tag: @tag).delete_all
        @tag.delete
      end
      redirect_to edit_user_path
    end
  end

  def new
    @tag = Tag.new
  end

  def create
    @tag = Tag.new(tags_params[:tag])
    @tag.save!
    if @tag.save
      User.all.each do |usr|
        ItemTag.create!(item: usr, tag_id: @tag.id, enabled: tags_params[:tag][:enabled_by_default])
      end
      Post.all.each { |post| ItemTag.create!(item: post, tag_id: @tag.id, enabled: false) }
      redirect_to edit_user_path
    else
      render :edit_user_path
    end
  end

  private

  def tags_params
    params.permit(:authenticity_token, :commit, :id, :_method, tags: {}, tag: %i[id name enabled_by_default])
  end
end
