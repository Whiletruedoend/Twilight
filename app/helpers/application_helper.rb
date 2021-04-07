module ApplicationHelper
  def markdown(text)
    renderer = { hard_wrap: true,
                 no_intra_emphasis: true,
                 fenced_code_blocks: true,
                 disable_indented_code_blocks: true,
                 autolink: true,
                 tables: true,
                 underline: true,
                 highlight: true }
    redcarpet = Redcarpet::Markdown.new(CustomRender.new(renderer))
    redcarpet.render(text).html_safe
  end
end