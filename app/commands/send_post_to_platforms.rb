class SendPostToPlatforms
  prepend SimpleCommand

  attr_accessor :post, :params

  def initialize(post, params)
    @params = params
    @post = post
  end

  def call
    params[:platforms].select{ |k,v| v == "1" }.each do |platform|
      case platform[0]

        when "telegram"
          channel_ids = Rails.configuration.credentials['telegram']['channel_ids']
          next if channel_ids.empty?

          channel_ids.each do |channel_id|
            title = post.title
            content = post.content
            text = "*#{title}*\n\n#{content}" # todo: fix bad request (message too long)
            msg = Telegram.bot.send_message({chat_id: channel_id, text: text, parse_mode: "markdown"})
            PlatformPost.create!(identifier: { chat_id: msg["result"]["chat"]["id"], message_id: msg["result"]["message_id"] }, platform: Platform.find_by_title(platform), post: @post)
          end

        else # todo: moare platforms!
          nil
      end
    end
  end

end