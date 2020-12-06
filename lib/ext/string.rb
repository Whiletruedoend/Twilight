class String
  def replace_markdown_to_symbols
    self.gsub("_", "\\_").gsub("*", "\\*").gsub("[", "\\[").gsub("`", "\\`")
  end
end