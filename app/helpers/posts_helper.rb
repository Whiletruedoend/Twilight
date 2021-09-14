# frozen_string_literal: true

module PostsHelper
  def get_post_tags(post)
    tags = post.active_tags_names.join(' ')
    tags.presence || 'no tags'
  end

  def get_published_platforms(post)
    post.platform_posts.map { |p| { name: p.platform.title, link: post_link(p) } }
  end

  def post_link(post)
    case p.platform.title
    when 'telegram'
      chat = Telegram.bot.get_chat(chat_id: post.identifier['chat_id'])
      if chat['result']['username'].present? && (chat['result']['type'] != 'private')
        "https://t.me/#{chat['result']['username']}/#{post.identifier['message_id']}"
      end
      # else # TODO: moare platform support!
      # nil
    end
  end

  def get_full_attachment_link(att)
    "http://#{Rails.configuration.credentials[:host]}:#{Rails.configuration.credentials[:port]}#{url_for(att)}"
  end

  def table_link_columns
    content = ''

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
    content = ''

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
    content = ''
    attachments_count = post.content_attachments&.count || 0
    size =
      case attachments_count
      when 1
        300
      when 2
        250
      when 3
        200
      when 4, 5
        150
      else
        100
      end

    documents = post.content_attachments.select { |b| !b.image? && !b.video? && !b.audio? }
    if documents.any?
      documents.each do |att|
        content += "<br><a target=\"_blank\" href=\"#{get_full_attachment_link(att)}\">
        #{I18n.t('posts.download')} #{truncate(att.filename.to_s, length: 100)} </a>"
      end
    end
    content += '<br><br>' if documents.any?

    post.content_attachments&.each do |att|
      if att.image?
        content += "<a target=\"_blank\" href=\"#{get_full_attachment_link(att)}\">
                     #{image_tag url_for(att.variant(resize_to_limit: [size, size]))}</a>"
      elsif att.video?
        content += "<a target=\"_blank\" href=\"#{get_full_attachment_link(att)}\">
                     #{image_tag url_for(att.preview(resize_to_limit: [size, size]).processed)}</a>"
      elsif att.audio?
        content += "<a target=\"_blank\" href=\"#{get_full_attachment_link(att)}\">
                     #{audio_tag(url_for(att), autoplay: false, controls: true)}</a>"
      end
    end
    content.html_safe
  end

  def display_comment_attachments(comment)
    content = ''
    comment.attachments.each do |att|
      content +=
        if att.image?
          "<a target=\"_blank\" href=\"#{url_for(att)}\">
          #{image_tag url_for(att.variant(resize_to_limit: [100, 100]))}</a>"
        elsif att.video?
          "<a target=\"_blank\" href=\"#{url_for(att)}\">
          #{image_tag url_for(att.preview(resize_to_limit: [100, 100]).processed)}</a>"
        elsif att.audio?
          "<a target=\"_blank\" href=\"#{url_for(att)}\">
          #{audio_tag(url_for(att), autoplay: false, controls: true)}</a>"
        else
          "<a target=\"_blank\" href=\"#{url_for(att)}\">
          #{image_tag('/assets/file.png', height: 100, width: 100)}</a>"
        end
    end
    content.html_safe
  end
end
