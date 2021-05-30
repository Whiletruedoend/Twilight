class CustomRender < Redcarpet::Render::HTML
  include Sprockets::Rails::Helper

  # detect width and height from ![photo](link.jpg =300x150)
  def image(link, title, alt_text)
    wxh = link.match(/\ =([^\>]+)[\D]([^\D]+)/)
    if wxh.present?
      "<img src='#{link.gsub(wxh[0], "")}' title='#{title}' alt='#{alt_text}' width='#{wxh[1]}' height='#{wxh[2]}'></img>"
      #image_tag(link.gsub(wxh[0], ""), { :title => title, :alt => alt_text, :width => wxh[1], :height => wxh[2] })
    else
      "<img src='#{link}' title='#{title}' alt='#{alt_text}'></img>"
      #image_tag(link, { :title => title, :alt => alt_text })
    end
  end


  def autolink(link, link_type)
    case link_type
    when :url then url_link(link)
    when :email then email_link(link)
    end
  end

  def url_link(link)
    youtube_id = link.match(/http.*:\/[^\\D>]+youtube.[^\\D>]+\/watch\?v=([^\\D>]+)/)
    youtube_id.present? ? youtube_link(youtube_id[1]) : normal_link(link)
  end
  def youtube_link(video_id)
    "<iframe frameborder=\"0\" width=\"600\" height=\"400\" src=\"https://www.youtube.com/embed/#{video_id}?autoplay=0&fs=1&iv_load_policy=3&showinfo=1&rel=0&cc_load_policy=0&start=0&end=0\" allow=\"accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture\" allowfullscreen></iframe>"
      #"<iframe width=\"600\" height=\"400\" src=\"//www.youtube.com/embed/#{video_id}?rel=0\" frameborder=\"0\" allowfullscreen></iframe>"
  end
  def normal_link(link)
    "<a href=\"#{link}\">#{link}</a>"
  end
  def email_link(email)
    "<a href=\"mailto:#{email}\">#{email}</a>"
  end
end