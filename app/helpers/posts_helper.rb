# frozen_string_literal: true

module PostsHelper
  def get_post_tags(post)
    tags = post.active_tags_names.join(' ')
    tags.presence || 'no tags'
  end

  def get_full_attachment_link(att)
    "#{request.base_url}#{url_for(att)}"
  end

  def display_attachments(post)
    content = ''

    documents = post.attachments&.select { |b| !b.image? && !b.video? && !b.audio? }
    if documents.any?
      documents.each do |att|
        content += "<br><a target=\"_blank\" href=\"#{get_full_attachment_link(att)}\">
        #{I18n.t('posts.download')} #{truncate(att.filename.to_s, length: 100)} </a>"
      end
    end
    content += '<br><br>' if documents.any?

    content += "<div class=\"attachments\">"
    post.attachments.each do |att|
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
    documents = post.attachments&.select { |b| !b.image? && !b.video? && !b.audio? }
    if documents.any?
      documents.each do |att|
        content += "<br><a target=\"_blank\" href=\"#{get_full_attachment_link(att)}\">
        #{I18n.t('posts.download')} #{truncate(att.filename.to_s, length: 100)} </a>"
      end
    end
    content += '<br><br>' if documents.any?

    post.attachments.each do |att|
      full_att_link = get_full_attachment_link(att)
      if att.image?
        content += link_to image_tag(full_att_link), full_att_link, target: '_blank'.to_s
        content += '<br>'
      elsif att.video?
        content += link_to full_att_link.to_s
        content += '<br>'
      elsif att.audio?
        content += link_to full_att_link.to_s
        content += '<br>'
      end
    end
    content += '<br>' if post.attachments.present?
    content.html_safe
  end

  # TODO: group attachments by type, better front-end
  def display_feed_attachments(post)
    content = ''

    documents = post.attachments&.select { |b| !b.image? && !b.video? && !b.audio? }
    if documents.any?
      documents.each do |att|
        content += "<a target=\"_blank\" href=\"#{get_full_attachment_link(att)}\">
        #{I18n.t('posts.download')} #{truncate(att.filename.to_s, length: 100)} </a>"
      end
    end

    content += "<div class=\"attachments\">"
    post.attachments.each do |att|
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

    item = Post.where(privacy: privacy, is_hidden: false)
    item += users_item if users_item.present?

    tags.map do |tag|
      item_tags = ItemTag.where(tag: tag, enabled: true, item: item)
      { id: tag.id, name: tag.name, count: item_tags.count }
    end
  end

  def render_title(post)
    post.title.present? ? link_markdown(post.title).html_safe : "##{post.id}"
  end

  def render_published_platforms(post)
    content = ''
    post.published_platforms.each_with_index do |(k,v), i|
      vv = v.reject{ |vv| vv[:channel_name].nil?}.uniq{ |u| u[:channel_name] }
      next if vv.empty?
      content += ' | ' if i != 0
      content += "#{k.capitalize}: "
      vv.each_with_index do |vvv, ii|
        content += vvv[:url].present? ? link_to(vvv[:channel_name], vvv[:url]) : link_to("#{vvv[:channel_name]} (Private)", "#")
        content += ', ' if ii != vv.size - 1
      end
    end
    # content += '-' if content.empty? # Post present, but channel was deleted
    content.html_safe
  end

  def render_feed_published_flatforms(post)
    content = ''
    post.published_platforms.each_with_index do |(k,v), i|
      vv = v.reject{ |vv| vv[:channel_name].nil?}.uniq{ |u| u[:channel_name] }
      p_class = "platform-tg" if k == "telegram"
      p_class = "platform-mx" if k == "matrix"
      next if vv.empty?
      vv.each_with_index do |vvv, ii|
        content += vvv[:url].present? ? link_to(vvv[:channel_name], vvv[:url], class: p_class) : link_to("#{vvv[:channel_name]} (Private)", "#", class: p_class)
      end
    end
    content.html_safe
  end

  def link_markdown(title)
    title.gsub(/\[(.*?)\]\((.*?)\)/) { |_m| "<a href=\"#{Regexp.last_match(2)}\">#{Regexp.last_match(1)}</a>" }
  end
end
