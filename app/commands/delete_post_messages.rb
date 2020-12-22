class DeletePostMessages
  prepend SimpleCommand

  attr_accessor :post

  def initialize(post)
    @post = post
  end

  def call
    post.platform_posts.each do |platform_post|
      case platform_post.platform.title
        when "telegram"
          begin
            if platform_post.content.has_attachments?
              platform_post.identifier.each { |att| Telegram.bot.delete_message({ chat_id: att["chat_id"], message_id: att["message_id"] }) }
            else
              Telegram.bot.delete_message({ chat_id: platform_post[:identifier]["chat_id"], message_id: platform_post[:identifier]["message_id"] })
            end
          rescue # Message don't delete (if bot don't have access to message)
            Rails.logger.error("Failed delete telegram messages at #{Time.now.utc.iso8601}")
          end
        else
      end
    end
  end
end