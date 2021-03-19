class ChannelsController < ApplicationController

  before_action :authenticate_user!
  before_action :check_admin

  def check_admin
    redirect_to root_path unless current_user.is_admin
  end

  def edit
  end

  def update
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
