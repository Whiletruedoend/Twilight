# frozen_string_literal: true

class Platform::DeleteTelegramComments
  prepend SimpleCommand

  attr_accessor :comms

  def initialize(comms)
    @comms = comms
  end

  def call
    @comms.each do |comm|
      if comm.channel&.nil? # Comment from linked group
        linked_channel_ids = comm.post.published_channels.map{ |ch| [ch.id, ch.options.dig("linked_chat_id")] }.to_h.compact_blank
        channel_id = linked_channel_ids.find { |k,v| v == comm[:identifier].dig('reply_to_message', 'sender_chat', 'id') }&.first
        channel = Channel.find(channel_id)
        token = channel.token&.to_s
      else
        channel = comm.channel
        token = channel.token&.to_s
      end
      bot = Twilight::Application::CURRENT_TG_BOTS&.dig(token, :client)
      if comm.has_attachments?
        comm.identifier.each do |att|
          bot.delete_message({ chat_id: att['chat_id'], message_id: att['message_id'] })
        end
      else
        bot.delete_message({ chat_id: comm[:identifier]['chat_id'],
                             message_id: comm[:identifier]['message_id'] })
      end
    rescue StandardError # Message don't delete (if bot don't have access to message)
      Rails.logger.error("Failed to delete telegram comments at #{Time.now.utc.iso8601}".red)
    end
  end
end
