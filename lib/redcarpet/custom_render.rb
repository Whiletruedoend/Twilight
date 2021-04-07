class CustomRender < Redcarpet::Render::HTML
  include Sprockets::Rails::Helper

  # detect width and height from ![photo](link.jpg =300x150)
  def image(link, title, alt_text)
    wxh = link.match(/\ =([^\>]+)[\D]([^\D]+)/)
    if wxh.present?
      image_tag(link.gsub(wxh[0], ""), { :title => title, :alt => alt_text, :width => wxh[1], :height => wxh[2] })
    else
      image_tag(link, { :title => title, :alt => alt_text })
    end
  end
end