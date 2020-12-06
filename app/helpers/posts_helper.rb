module PostsHelper
  def get_post_tags(post)
    tags = post.active_tags_names.join(' ')
    tags.present? ? tags : "no tags"
  end

  def get_published_platforms(post)
    post.platform_posts.map do |p| { name: p.platform.title, link: get_post_link(p) } end
  end

  def get_post_link(p)
    case p.platform.title
    when "telegram"
      chat = Telegram.bot.get_chat(chat_id: p.identifier["chat_id"])
      "https://t.me/#{chat["result"]["username"]}/#{p.identifier["message_id"]}" if chat["result"]["username"].present? && (chat["result"]["type"] != "private")
      else # todo: moare platform support!
        nil
    end
  end
end