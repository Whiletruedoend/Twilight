# frozen_string_literal: true

module ApplicationHelper
  def markdown(text)
    renderer = { hard_wrap: true,
                 no_intra_emphasis: true,
                 fenced_code_blocks: true,
                 disable_indented_code_blocks: true,
                 space_after_headers: true,
                 tables: true,
                 underline: true,
                 highlight: true }
    redcarpet = Redcarpet::Markdown.new(CustomRender.new(renderer), autolink: true)
    redcarpet.render(text).html_safe
  end

  def asset_exist?(path)
    if Rails.configuration.assets.compile
      Rails.application.precompiled_assets.include? path
    else
      Rails.application.assets_manifest.assets[path].present?
    end
  end  

  def current_theme
    return "#{params[:theme]}_theme" if params.dig('theme').present? && asset_exist?("#{params[:theme]}_theme.css")
    current_user&.options&.dig('theme') || 'default_theme'
  end
end
