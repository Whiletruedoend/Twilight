# frozen_string_literal: true

class ChannelsController < ApplicationController
  before_action :authenticate_user!

  def set_tags
    set_meta_tags(title: 'Channels',
                  description: 'Manage your channels',
                  keywords: 'Twilight, Notes, channels')
  end

  def edit
    authorize! current_channel, to: :update?
  end

  def update
    authorize! current_channel

    command = CheckChannel.call(current_channel, channels_params)
    unless command.success?
      redirect_to edit_channel_path, custom_error: command.errors.full_messages
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
      redirect_to new_channel_path, custom_error: command.errors.full_messages
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

    token = current_channel.token
    bot = Twilight::Application::CURRENT_TG_BOTS&.dig(token.to_s, :client)
    Platform::ManageTelegramPollers.call(bot, 'delete') if bot.present?
    current_channel.platform_posts.destroy_all
    current_channel.destroy

    redirect_to edit_user_path
  end

  private

  def channels_params
    params.permit(:_method, :id, :authenticity_token, :commit, channel: {})
  end
end
