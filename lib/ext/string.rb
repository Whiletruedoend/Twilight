class String
  # https://regex101.com/
  def replace_html_to_tg_markdown
    # remove <p> tag
    a = self
    a.gsub!("<p>", "")
    a.gsub!("</p>", "")
    # replace <strong> tag
    a.gsub!("<strong>", "<b>")
    a.gsub!("</strong>", "</b>")
    # replace list, make it 'code-style'
    a.gsub!("<li>", "* ")
    a.gsub!("</li>", "")
    # numeric list
    a.gsub!("<ol>", "")
    a.gsub!("</ol>", "")
    # list
    a.gsub!("\n\n<ul>", "<code>")
    a.gsub!("\n</ul>", "</code>")
    # replace 'images', make it 'link-style'
    # <p><a href=\"https://habr.com/ru/\">LINK</a> TEST <img src=\"https://hsto.org/getpro/habr/post_images/0bd/696/a20/0bd696a200f7bb07f6813bfa3cef684c.webp\" alt=\"IMAGE\"></p>\n
    a.gsub!("<img src", "<a href")
    a.gsub!(/ alt=\"([^\>]+)">/) {|m| m.gsub!(/ alt=\"([^\>]+)">/, ">#{$1}</a>") }
    a
  end
  def replace_html_to_mx_markdown
    a = self
    # replace 'images', make it 'link-style'
    # <p><a href=\"https://habr.com/ru/\">LINK</a> TEST <img src=\"https://hsto.org/getpro/habr/post_images/0bd/696/a20/0bd696a200f7bb07f6813bfa3cef684c.webp\" alt=\"IMAGE\"></p>\n
    a.gsub!("<img src", "<a href")
    a.gsub!(/ alt=\"([^\>]+)">/) {|m| m.gsub!(/ alt=\"([^\>]+)">/, ">#{$1}</a>") }
    a
  end
end