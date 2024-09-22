# frozen_string_literal: true

class ImportFiles
  prepend SimpleCommand

  attr_accessor :current_user, :file

  def initialize(current_user, file)
    @current_user = current_user
    @file = file
  end

  def call
    file_blob = ActiveStorage::Blob.find_signed!(@file)

    return unless file_blob.content_type == 'text/markdown' # zip currently not supports

    text = File.read(ActiveStorage::Blob.service.send(:path_for, file_blob.key))

    # Parse post title
    title = text.match("## ([^\n]+)")
    if title.present?
      title_offset = title.offset(0)
      # +3 - "## ", -3 - "\n\r\n" (or something like that)
      # check if '## Test' is not start of file
      content_title = (title_offset.include?(0) ? text[title_offset[0] + 3, title_offset[1] - 3] : nil)
      content_title = nil if content_title.present? && !content_title.match?(/[^\s]+/) # only spaces or special chars
    end
    text = text[title_offset[1] + 1..(text.length)] if content_title.present?

    # Parse post date
    date = text.match("<TW_METADATA>\r\n  <DATE>([^\\>]+)<\\/DATE>")
    date = date.captures.first if date.present?

    begin
      date = date.to_datetime if date.present?
      date = DateTime.now if date.present? && (date > DateTime.now)
    rescue StandardError
      date = DateTime.now
    end

    # Parse post privacy
    privacy = text.match('<PRIVACY>([^\\D>]+)<\\/PRIVACY>')
    privacy = privacy.captures.first if privacy.present?

    begin
      privacy = privacy.to_i if privacy.present?
      privacy = 2 if privacy.nil?
    rescue StandardError
      privacy = 2
    end

    # Parse post privacy
    is_hidden = text.match('<IS_HIDDEN>([^\\D>]+)<\\/IS_HIDDEN>')
    is_hidden = is_hidden.captures.first if is_hidden.present?

    begin
      is_hidden = !is_hidden.to_i.zero? if is_hidden.present?
    rescue StandardError
      is_hidden = false
    end

    # Parse post category
    category = text.match('<CATEGORY>([^\\D>]+)<\\/CATEGORY>')
    category = category.captures.first if category.present?
    category = category.to_i if category.present?
    category = nil if @current_user.categories.find_by(id: category).blank?

    # Create post, lol
    post = Post.create!(user: @current_user, title: content_title, privacy: privacy, is_hidden: is_hidden,
                        category_id: category, created_at: date)

    # Parse post tags
    tags = text.match('<TAGS>([^\\>]+)<\\/TAGS>')
    tags = tags.captures.first if tags.present?

    if tags.present?
      tags = tags.split(',')
      used_tags = []
      tags.each do |t|
        tag = Tag.find_by(name: t)
        if tag.present?
          ItemTag.create!(item: post, tag_id: tag.id, enabled: true)
          used_tags << tag.id
        else
          tag = Tag.create!(name: t)
          # for other posts
          Post.all.each do |p|
            if p == post
              ItemTag.create!(item: p, tag_id: tag.id,
                              enabled: true)
            else
              ItemTag.create!(
                item: p, tag_id: tag.id, enabled: false
              )
            end
          end
          User.all.each { |u| ItemTag.create!(item: u, tag_id: tag.id, enabled: true) } # why not?
        end
      end
      if used_tags.any?
        Tag.where.not(id: used_tags).each do |t|
          ItemTag.create!(item: post, tag_id: t.id, enabled: false)
        end
      end
    else
      Tag.all.each { |t| ItemTag.create!(item: post, tag_id: t.id, enabled: false) }
    end

    # Delete metadata from text
    metadata = text.match('(<TW_METADATA>+([^.])+<\\/TW_METADATA>)')
    text = text[0..metadata.offset(0)[0] - 1] if metadata.present?

    Content.create!(user: post.user, post: post, text: text, has_attachments: false) # .md not contains attachments
    post
  end
end
