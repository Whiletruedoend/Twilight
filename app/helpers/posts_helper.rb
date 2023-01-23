# frozen_string_literal: true

module PostsHelper
  def host_link
    "http://#{Rails.configuration.credentials[:host]}:#{Rails.configuration.credentials[:port]}"
  end

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
    "#{host_link}#{url_for(att)}"
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
        :thumb_300
      when 2
        :thumb_250
      when 3
        :thumb_200
      when 4, 5
        :thumb_150
      else
        :thumb_100
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
        content += link_to image_tag(url_for(att.variant(size))), url_for(att), target: "_blank".to_s
      elsif att.video?
        content += video_tag(url_for(att), controls: true, preload: 'none', poster: url_for(att.preview(resize_to_limit: [200, 200]).processed)).to_s
      elsif att.audio?
        content += link_to audio_tag(url_for(att), autoplay: false, controls: true), url_for(att), target: "_blank".to_s
      end
    end
    content.html_safe
  end

  # TODO: group attachments by type, better front-end
  def display_feed_attachments(post)
    content = ''

    documents = post.content_attachments.select { |b| !b.image? && !b.video? && !b.audio? }
    if documents.any?
      documents.each do |att|
        content += "<a target=\"_blank\" href=\"#{get_full_attachment_link(att)}\">
        #{I18n.t('posts.download')} #{truncate(att.filename.to_s, length: 100)} </a>"
      end
    end

    post.content_attachments&.each do |att|
      if att.image?
        content += image_tag url_for(att), id: 'zoom-bg'.to_s
      elsif att.video?
        content += "<video width=\"100%\" height=\"100%\" controls>
                      <source src=\"#{url_for(att)}\" type=\"video/mp4\">
                      Your browser does not support the video tag.
                    </video>"
        # content += "<a target=\"_blank\" href=\"#{get_full_attachment_link(att)}\">
        #             #{image_tag url_for(att.preview(resize_to_limit: [50, 50]).processed)}</a>"
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
          link_to image_tag(url_for(att.variant(:thumb_100))), url_for(att), target: "_blank".to_s
        elsif att.video?
          "<a target=\"_blank\" href=\"#{url_for(att)}\">
          #{image_tag url_for(att.preview(:thumb_100).processed)}</a>"
        elsif att.audio?
          link_to audio_tag(url_for(att), autoplay: false, controls: true), url_for(att), target: "_blank".to_s
        else
          "<a target=\"_blank\" href=\"#{url_for(att)}\">
          #{image_tag('/assets/file.png', height: 100, width: 100)}</a>"
        end
    end
    content.html_safe
  end

  def tags_with_count_list(tags)
    if current_user.present?
      users_item = Post.where(privacy: 2, user: current_user)
      privacy = [0, 1]
    else
      users_item = []
      privacy = [0]
    end

    item = Post.where(privacy: privacy)
    item += users_item if users_item.present?

    tags.map do |tag|
      item_tags = ItemTag.where(tag: tag, enabled: true, item: item)
      { id: tag.id, name: tag.name, count: item_tags.count }
    end
  end

  def render_title(post)
    post.title.present? ? link_markdown(post.title).html_safe : "##{post.id}"
  end

  def link_markdown(title)
    title.gsub(/\[(.*?)\]\((.*?)\)/) { |_m| "<a href=\"#{Regexp.last_match(2)}\">#{Regexp.last_match(1)}</a>" }
  end
end
