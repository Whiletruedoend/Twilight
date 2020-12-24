unless current_user.present? || (params.has_key?(:rss_token) && User.find_by_rss_token(params[:rss_token].to_s).present?)
  return xml.title "Access denied! Please, use rss_token from account settings :/"
end

xml.instruct! :xml, :version=>"1.0"
xml.rss version: '2.0', 'xmlns:atom' => 'http://www.w3.org/2005/Atom' do

  xml.channel do
    xml.title 'Title'
    xml.description 'Description'
    xml.link root_url
    xml.language 'ru'
    xml.tag! 'atom:link', rel: 'self', type: 'application/rss+xml', href: "http://#{Rails.configuration.credentials[:host]}:#{Rails.configuration.credentials[:port]}/rss?rss_token=#{(params.has_key?(:rss_token) && User.find_by_rss_token(params[:rss_token].to_s).present?) ? params[:rss_token] : (current_user&.rss_token || "none")}"
    xml.ttl "60"

    for post in @posts
      xml.item do
        xml.title post.title
        xml.description(post.get_content)
        #xml.creator post.user.login
        xml.author post.user.login

        post.get_content_attachments.each do |att|
          xml.image do
            link = get_image_link(att)
            xml.url link
            xml.link link
          end
        end

        xml.pubDate(post.created_at.rfc2822)
        xml.guid post_url(post)
        xml.link post_url(post)
      end
    end

  end

end
