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
            Telegram.bot.delete_message({ chat_id: platform_post[:identifier]["chat_id"], message_id: platform_post[:identifier]["message_id"] })
          rescue # Message don't delete (if bot don't have access to message)
          end
        else
      end
    end
  end
end