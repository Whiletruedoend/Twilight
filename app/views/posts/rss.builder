unless current_user.present? || (params.has_key?(:rss_token) && User.find_by_rss_token(params[:rss_token].to_s).present?)
  return xml.title "Access denied! Please, use rss_token from account settings :/"
end

@markdown = Redcarpet::Markdown.new(CustomRender.new({ hard_wrap: true,
                                                       no_intra_emphasis: true,
                                                       fenced_code_blocks: true,
                                                       disable_indented_code_blocks: true,
                                                       tables: true,
                                                       underline: true,
                                                       highlight: true}), autolink: true)

xml.instruct! :xml, :version=>"1.0"
xml.rss version: '2.0', 'xmlns:atom' => 'http://www.w3.org/2005/Atom' do

  xml.channel do
    xml.title "#{Rails.configuration.credentials[:title]}"
    xml.description "#{Rails.configuration.credentials[:rss_description]}"
    xml.link root_url
    xml.language 'ru'
    xml.tag! 'atom:link', rel: 'self', type: 'application/rss+xml', href: "http://#{Rails.configuration.credentials[:host]}:#{Rails.configuration.credentials[:port]}/rss?rss_token=#{(params.has_key?(:rss_token) && User.find_by_rss_token(params[:rss_token].to_s).present?) ? params[:rss_token] : (current_user&.rss_token || "none")}"
    xml.ttl "60"

    for post in @posts
      xml.item do
        xml.title post.title

        text = post.get_content

        attachments = post.get_content_attachments
        attachments = attachments.map do |attachment|
          case
          when attachment.image?
            image_tag(get_full_attachment_link(attachment))
          when attachment.video?
            video_tag(get_full_attachment_link(attachment), controls: true, preload: 'none')
          when attachment.audio?
            audio_tag(get_full_attachment_link(attachment), autoplay: false, controls: true)
          else
            "<a target=\"_blank\" href=\"#{get_full_attachment_link(attachment)}\"> #{image_tag url_for('/assets/file.png')} </a>"
          end
        end.join(' ')+"<br>" if attachments.present?
        full_text = attachments.present? ? attachments + text : text

        xml.description @markdown.render(full_text)
        #xml.creator post.user.login
        xml.author post.user.login
        xml.category post.category.name if post.category.present?

        xml.pubDate(post.created_at.rfc2822)
        xml.guid post_url(post)
        xml.link post_url(post)
      end
    end

  end

end
