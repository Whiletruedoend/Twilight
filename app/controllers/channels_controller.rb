class ChannelsController < ApplicationController

  before_action :authenticate_user!
  before_action :check_admin

  def check_admin
    redirect_to root_path unless current_user.is_admin
  end

  def edit
    @channel = Channel.find_by_id(params[:id])
    if @channel.present?
      return render file: "#{Rails.root}/public/404.html", layout: false, status: 404 if @channel.user != current_user
    else
      render file: "#{Rails.root}/public/404.html", layout: false, status: 404
    end
  end

  def update
    @channel = Channel.find_by_id(params[:id])
    if @channel.present?
      return render file: "#{Rails.root}/public/404.html", layout: false, status: 404 if @channel.user != current_user
    else
      return render file: "#{Rails.root}/public/404.html", layout: false, status: 404
    end

    command = CheckChannel.call(@channel, channels_params)
    unless command.success?
      redirect_to edit_channel_path, :alert => command.errors.full_messages
      return
    end

    token = channels_params[:channel][:token]
    room = channels_params[:channel][:room]
    enabled = channels_params[:channel][:enabled]

    if @channel.update(token: token, room: room, enabled: enabled)
      redirect_to edit_user_path
    else
      render :edit
    end
  end

  def new
    @channel = Channel.new
  end

  def create
    @channel = Channel.new

    command = CheckChannel.call(@channel, channels_params)
    unless command.success?
      redirect_to new_channel_path, :alert => command.errors.full_messages
      return
    end

    @channel.user = current_user
    @channel.platform = Platform.find_by_title(channels_params[:channel][:platform])
    @channel.token = channels_params[:channel][:token]
    @channel.room = channels_params[:channel][:room]
    @channel.enabled = true

    if @channel.save
      redirect_to edit_user_path
    else
      render :new
    end
  end

  def destroy
    @channel = Channel.find(params[:id])
    if @channel.user == current_user
      #@channel.avatar.destroy!
      @channel.delete
    end
    redirect_to edit_user_path
  end

  private
  def channels_params
    params.permit(:_method, :id, :authenticity_token, :commit, :channel => {})
  end
end
