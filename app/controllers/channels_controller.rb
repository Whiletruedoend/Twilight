# frozen_string_literal: true

class ChannelsController < ApplicationController
  before_action :authenticate_user!

  def edit
    authorize! current_channel, to: :update?
  end

  def update
    authorize! current_channel

    command = CheckChannel.call(current_channel, channels_params)
    unless command.success?
      redirect_to edit_channel_path, alert: command.errors.full_messages
      return
    end

    token = channels_params[:channel][:token]
    room = channels_params[:channel][:room]
    enabled = channels_params[:channel][:enabled]

    if current_channel.update(token: token, room: room, enabled: enabled)
      redirect_to edit_user_path
    else
      render :edit
    end
  end

  def new
    authorize! current_user, to: :create_channels?

    @current_channel = Channel.new
  end

  def create
    authorize! current_user, to: :create_channels?

    @current_channel = Channel.new

    command = CheckChannel.call(@current_channel, channels_params)
    unless command.success?
      redirect_to new_channel_path, alert: command.errors.full_messages
      return
    end

    @current_channel.user = current_user
    @current_channel.platform = Platform.find_by(title: channels_params[:channel][:platform])
    @current_channel.token = channels_params[:channel][:token]
    @current_channel.room = channels_params[:channel][:room]
    @current_channel.enabled = true

    if @current_channel.save
      redirect_to edit_user_path
    else
      render :new
    end
  end

  def destroy
    authorize! current_channel

    # current_channel.avatar.destroy!
    current_channel.delete

    redirect_to edit_user_path
  end

  private

  def channels_params
    params.permit(:_method, :id, :authenticity_token, :commit, channel: {})
  end
end
