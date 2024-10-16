# frozen_string_literal: true

xml.instruct! :xml, version: '1.0'
xml.rss version: '2.0', 'xmlns:atom' => 'http://www.w3.org/2005/Atom' do
  xml.channel do
    xml.title Rails.configuration.credentials[:title].to_s
    xml.description Rails.configuration.credentials[:rss_description].to_s
    xml.link root_url
    xml.language 'ru'
    xml.tag! 'atom:link', rel: 'self', type: 'application/rss+xml',
                          href: "#{request.base_url}/rss?token=#{params.key?(:token) && User.find_by(rss_token: params[:token].to_s).present? ? params[:token] : (current_user&.rss_token || 'none')}"
    xml.ttl '60'

    @posts.each do |post|
      xml.item do
        if post.title.present?
          xml.title @markdown.render(post.title)
        else
          xml.title "##{post.uuid}"
        end

        text = post.text

        attachments = post.attachments
        if attachments.present?
          attachments = attachments.map do |attachment|
            if attachment.image?
              image_tag(get_full_attachment_link(attachment))
            elsif attachment.video?
              video_tag(get_full_attachment_link(attachment), controls: true, preload: 'none')
            elsif attachment.audio?
              audio_tag(get_full_attachment_link(attachment), autoplay: false, controls: true)
            else
              "<a target=\"_blank\" href=\"#{get_full_attachment_link(attachment)}\"> #{image_tag url_for('/assets/file.png')} </a>"
            end
          end.join(' ') + '<br>'
        end
        full_text = attachments.present? ? attachments + text : text

        xml.description @markdown.render(full_text)
        # xml.creator post.user.login
        xml.author display_name(post.user)
        xml.category post.category.name if post.category.present?

        xml.pubDate(post.created_at.rfc2822)
        xml.guid post_url(post)
        xml.link post_url(post)
      end
    end
  end
end
