class String
  def replace_html_to_tg_markdown
    self.gsub("<p>", "").gsub("</p>", "").gsub("<strong>", "<b>").gsub("</strong>", "</b>").gsub("<li>", "* ").gsub("</li>", "").gsub("\n\n<ul>", "<code>").gsub("\n</ul>", "</code>")#.gsub("_", '\\_').gsub("*", '\\*')#.gsub("<code>", "`").gsub("</code>", "`")#.gsub("<b>", "*").gsub("</b>", "*").gsub("<em>", "_").gsub("</em>", "_").gsub("<h1>", "").gsub("</h1>", "").gsub("<h2>", "").gsub("</h2>", "").gsub("<h3>", "").gsub("</h3>", "").gsub("<h4>", "").gsub("</h4>", "").gsub("</h4>", "").gsub("<a href=\"", '').gsub("</a>", "").gsub("`", "\\`")
  end
end