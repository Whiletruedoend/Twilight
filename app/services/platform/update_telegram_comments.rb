# frozen_string_literal: true

class Platform::UpdateTelegramComments
  prepend SimpleCommand

  attr_accessor :comms, :user, :text

  def initialize(comms, user, text)
    @comms = comms
    @user = user
    @text = text
  end

  # TODO: Attachments update support?
  def call
    @comms.each do |comm|
      post_user = comm.post.user
      
      if @user.id != comm.channel.user_id
        if comm.user_id.present? && (@user.id != comm.user_id)
          send_text = "#{post_user.displayed_name} (Edited by #{@user.displayed_name}):\n#{@text}"
        else
          send_text = "#{comm.user.displayed_name}:\n#{@text}"
        end
      else
        if comm.user_id.present? && (@user.id != comm.user_id)
          send_text = "#{comm.user.displayed_name} (Edited by #{@user.displayed_name}):\n#{@text}"
        else
          send_text = "#{@text}"
        end
      end
      begin
        bot = get_tg_bot(comm)
        if comm.identifier.is_a?(Array)
          comm.identifier.each do |ident|
            bot.edit_message_text({ chat_id: ident['chat_id'],
                                    message_id: ident['message_id'],
                                    text: send_text,
                                    parse_mode: 'html'
                                  })
          end
          comm.update!(text: @text, is_edited: true)
        else
          bot.edit_message_text({ chat_id: comm.identifier['chat_id'],
                                  message_id: comm.identifier['message_id'],
                                  text: send_text,
                                  parse_mode: 'html'
                                })
          comm.update!(text: @text, is_edited: true)
        end
      rescue StandardError => e
        Rails.logger.error("Failed update telegram comment at #{Time.now.utc.iso8601}: #{e.message}".red)
        error_text = "Telegram (update comment: #{e.message})"
        Notification.create!(item: comm, user_id: user.id, event: "update", status: "error", text: error_text)
      end
    end
  end

  def get_tg_bot(comm)
    Twilight::Application::CURRENT_TG_BOTS&.dig(comm.channel.token.to_s, :client)
  end
end
