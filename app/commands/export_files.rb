class ExportFiles
  prepend SimpleCommand

  attr_accessor :post

  def initialize(post)
    @post = post
  end

  def call

    title = @post.title
    content_text = @post.get_content
    text = title.present? ? "## #{title}\n\n#{content_text}" : "#{content_text}"

    post_dir = "tmp/export/#{@post.id.to_s}"

    metadata = <<~TW_METADATA
                  \n\n<TW_METADATA>
                    <DATE>#{ @post.updated_at }</DATE>
                    <PRIVACY>#{ @post.privacy }</PRIVACY>
                    <TAGS>#{ ItemTag.where(enabled: true, item: @post).map { |item_tag| "#{item_tag.tag.name}" }.join(',') }</TAGS>
                  </TW_METADATA>
                TW_METADATA

    text += metadata #if text.present?

    FileUtils.mkdir_p(post_dir) unless File.directory?(post_dir)

    File.open("#{post_dir}/#{@post.id.to_s}.md", 'w') do |f|
      f.truncate(0) # delete old content if exists
      f.write(text)
    end

    if @post.get_content_attachments.any?
      @post.get_content_attachments.each do |attachment|
        filename = attachment.blob.filename.to_s
        FileUtils.cp(ActiveStorage::Blob.service.send(:path_for, attachment.blob.key), "#{post_dir}/#{filename}")
      end
    end

    if @post.get_content_attachments.any?
      output_file = "tmp/export/#{@post.id.to_s}.zip"
      zf = ZipFileGenerator.new(post_dir, output_file)
      zf.write
      { path: output_file, filename: "#{@post.id.to_s}.zip", type: "application/zip" }
    else
      { path: "#{post_dir}/#{@post.id.to_s}.md", filename: "#{@post.id.to_s}.md", type: "text/markdown" }
    end
  end
end