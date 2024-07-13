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
    "#{request.base_url}#{url_for(att)}"
  end

  def display_attachments(post)
    content = ''

    documents = post.content_attachments.select { |b| !b.image? && !b.video? && !b.audio? }
    if documents.any?
      documents.each do |att|
        content += "<br><a target=\"_blank\" href=\"#{get_full_attachment_link(att)}\">
        #{I18n.t('posts.download')} #{truncate(att.filename.to_s, length: 100)} </a>"
      end
    end
    content += '<br><br>' if documents.any?

    content += "<div class=\"attachments\">"
    post.content_attachments&.each do |att|
      if att.image?
        content += link_to image_tag(url_for(att)), url_for(att), target: '_blank'.to_s
      elsif att.video?
        content += video_tag(url_for(att), controls: true, preload: 'none',
                                           poster: url_for(att.preview(resize_to_limit: [200, 200]).processed)).to_s
      elsif att.audio?
        content += "<div class=\"audio-cover\">"
        content += "<div class=\"audio-title\">#{att.filename.to_s[0..64]}</div>"
        content += "<i class=\"fa fa-light fa-music\"></i>"
        content += "#{audio_tag(url_for(att), autoplay: false, controls: true)}"
        content += '</div>'
      end
    end
    content += '</div>'
    content.html_safe
  end

  # TODO
  def display_raw_attachments(post)
    content = ''
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
        content += link_to image_tag(url_for(att)), url_for(att), target: '_blank'.to_s
        content += '<br>'
      elsif att.video?
        content += link_to url_for(att).to_s
        content += '<br>'
      elsif att.audio?
        content += link_to url_for(att).to_s
        content += '<br>'
      end
    end
    content += '<br>' if post.content_attachments&.any?
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

    content += "<div class=\"attachments\">"
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
        content += "<div class=\"audio-cover\">"
        content += "<div class=\"audio-title\">#{att.filename.to_s[0..64]}</div>"
        content += "<i class=\"fa fa-light fa-music\"></i>"
        content += "#{audio_tag(url_for(att), autoplay: false, controls: true)}"
        content += '</div>'
      end
    end
    content += '</div>'
    content.html_safe
  end

  def display_comment_attachments(comment)
    content = ''
    comment.attachments.each do |att|
      content +=
        if att.image?
          link_to image_tag(url_for(att.variant(:thumb100))), url_for(att), target: '_blank'.to_s
        elsif att.video?
          "<a target=\"_blank\" href=\"#{url_for(att)}\">
          #{image_tag url_for(att.preview(:thumb100).processed)}</a>"
        elsif att.audio?
          link_to audio_tag(url_for(att), autoplay: false, controls: true), url_for(att), target: '_blank'.to_s
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
