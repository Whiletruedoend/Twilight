# frozen_string_literal: true

class ExportFiles
  prepend SimpleCommand

  attr_accessor :post

  def initialize(post)
    @post = post
    @markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, no_intra_emphasis: false, fenced_code_blocks: false,
                                                                 disable_indented_code_blocks: true, autolink: false,
                                                                 tables: false, underline: false, highlight: false)
  end

  def call
    title = @post.title
    content_text = ReverseMarkdown.convert(@markdown.render(@post.text), unknown_tags: :pass_through)
    text = title.present? ? "## #{title}\n\n#{content_text}" : content_text.to_s

    # ![p](...%20=..x..) => ![p](... =..x..)
    text = text.gsub(/!\[[^\>]+\]\([^\>]+(%20)=[0-9]+x[0-9]+\)/) { |m| m.gsub!("%20"," ") }

    post_dir = "tmp/export/#{@post.id}"

    metadata = <<~TW_METADATA
      \n\n<TW_METADATA>
        <DATE>#{@post.updated_at}</DATE>
        <PRIVACY>#{@post.privacy}</PRIVACY>
        <CATEGORY>#{@post.category_id}</CATEGORY>
        <TAGS>#{ItemTag.where(enabled: true, item: @post).map { |item_tag| item_tag.tag.name.to_s }.join(',')}</TAGS>
      </TW_METADATA>
    TW_METADATA

    text += metadata # if text.present?

    FileUtils.mkdir_p(post_dir) unless File.directory?(post_dir)

    File.open("#{post_dir}/#{@post.id}.md", 'w') do |f|
      f.truncate(0) # delete old content if exists
      f.write(text)
    end

    if @post.content_attachments.present?
      @post.content_attachments.each do |attachment|
        filename = attachment.blob.filename.to_s
        FileUtils.cp(ActiveStorage::Blob.service.send(:path_for, attachment.blob.key), "#{post_dir}/#{filename}")
      end
    end

    if @post.content_attachments.present?
      output_file = "tmp/export/#{@post.id}.zip"
      zf = ZipFileGenerator.new(post_dir, output_file)
      zf.write
      { path: output_file, filename: "#{@post.id}.zip", type: 'application/zip' }
    else
      { path: "#{post_dir}/#{@post.id}.md", filename: "#{@post.id}.md", type: 'text/markdown' }
    end
  end
end
