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

  def get_full_attachment_link(att)
    "http://#{Rails.configuration.credentials[:host]}:#{Rails.configuration.credentials[:port]}#{url_for(att)}"
  end

  def table_link_columns
    content = ""

    github = Rails.configuration.credentials[:links][:github]
    if github.present?
      content += "<tr>
                    <td><i class=\"fa fa-github\"></i></td>
                    <td><a target=\"_blank\" href=\"#{github}\">Github</a></td>
                  </tr>"
    end

    kinopoisk = Rails.configuration.credentials[:links][:kinopoisk]
    if kinopoisk.present?
      content += "<tr>
                    <td><i class=\"fa fa-video-camera\"></i></td>
                    <td><a target=\"_blank\" href=\"#{kinopoisk}\">Kinopoisk</a></td>
                  </tr>"
    end

    mal = Rails.configuration.credentials[:links][:mal]
    if mal.present?
      content += "<tr>
                    <td><i class=\"fa fa-list\"></i></td>
                    <td><a target=\"_blank\" href=\"#{mal}\">My Anime List</a></td>
                  </tr>".html_safe
    end

    content.html_safe
  end

  def table_contacts_columns
    content = ""

    telegram = Rails.configuration.credentials[:links][:telegram]
    if telegram.present?
      content += "<tr>
                    <td><i class=\"fa fa-telegram -o fa-fw\"></i></td>
                    <td><a target=\"_blank\" href=\"#{telegram}\">Telegram</a></td>
                  </tr>"
    end

    matrix = Rails.configuration.credentials[:links][:matrix]
    if matrix.present?
      content += "<tr>
                    <td><i class=\"fa fa-commenting -o fa-fw\"></i></td>
                    <td><a target=\"_blank\" href=\"#{matrix}\">Matrix</a> <--- prefer</td>
                  </tr>"
    end

    jabber = Rails.configuration.credentials[:links][:jabber]
    if jabber.present?
      content += "<tr>
                    <td><i class=\"fa fa-commenting-o -o fa-fw\"></i></td>
                    <td><a target=\"_blank\" href=\"#{jabber}\">Jabber</a></td>
                  </tr>"
    end

    content.html_safe
  end

  def display_attachments(post)
    content = ""
    size = case post.get_content_attachments.count
             when 1
               300
             when 2
               250
             when 3
               200
             when 4,5
               150
             else
               100
             end
    post.get_content_attachments&.each do |att|
      case
        when att.image?
          content += "<a target=\"_blank\" href=\"#{url_for(att)}\"> #{image_tag url_for(att.variant(resize_to_limit: [size, size]))}</a>"
        when att.video?
          content += "<a target=\"_blank\" href=\"#{url_for(att)}\"> #{image_tag url_for(att.preview(resize_to_limit: [size, size]).processed)}</a>"
        when att.audio?
          content += "<a target=\"_blank\" href=\"#{url_for(att)}\"> #{audio_tag(url_for(att), autoplay: false, controls: true)}</a>"
        else
          #content += "<a target=\"_blank\" href=\"#{url_for(att)}\"> #{image_tag("/assets/file.png", height: 75, width: 75)}</a>"
      end
    end
    content.html_safe
  end

  def display_comment_attachments(comment)
    content = ""
    comment.attachments.each do |att|
      case
        when att.image?
          content += "<a target=\"_blank\" href=\"#{url_for(att)}\"> #{image_tag url_for(att.variant(resize_to_limit: [100, 100]))}</a>"
        when att.video?
          content += "<a target=\"_blank\" href=\"#{url_for(att)}\"> #{image_tag url_for(att.preview(resize_to_limit: [100, 100]).processed)}</a>"
        when att.audio?
          content += "<a target=\"_blank\" href=\"#{url_for(att)}\"> #{audio_tag(url_for(att), autoplay: false, controls: true)}</a>"
        else
          content += "<a target=\"_blank\" href=\"#{url_for(att)}\"> #{image_tag("/assets/file.png", height: 100, width: 100)}</a>"
      end
    end
    content.html_safe
  end
end