# frozen_string_literal: true

class Platform::UpdateMatrixPosts
  prepend SimpleCommand

  attr_accessor :post, :params

  def initialize(post, base_url, params)
    @params = params
    @post = post
    @base_url = base_url

    @title = post.title
    @content = params[:post][:content]
    @deleted_attachments = @params[:deleted_attachments]
    @attachments_count = @post.content_attachments&.count || 0

    @markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, no_intra_emphasis: false, fenced_code_blocks: false,
                                                                 disable_indented_code_blocks: true, autolink: false,
                                                                 tables: false, underline: false, highlight: false)
  end

  def call
    platform_posts = @post.platform_posts.where(platform: Platform.where(title: 'matrix'))
    need_delete_attachments = false

    platform_posts.joins(:content).where(contents: { has_attachments: true }).each do |platform_post|
      if platform_post.identifier.is_a?(Hash) && platform_post.identifier.dig('options', 'onlylink')
        room_id = platform_post[:identifier]['room_id']
        event_id = platform_post[:identifier]['event_id']
        edit_mx_onlylink_post(platform_post, room_id, event_id)
        next
      end
    end

    if @deleted_attachments.present?
      attachments = @deleted_attachments.to_unsafe_h
      del_att = attachments.select { |val| attachments[val] == '0' }
      need_delete_attachments = true if del_att.any?

      platform_posts.joins(:content).where(contents: { has_attachments: true }).each do |platform_post|
        next if platform_post.identifier.is_a?(Array) && platform_post.identifier[0].dig('options', 'onlylink')
        next if platform_post.identifier.is_a?(Hash) && platform_post.identifier.dig('options', 'onlylink')

        matrix_token = platform_post.channel.token
        server = platform_post.channel.options['server']

        deleted_indexes = []
        del_att.each_key do |k|
          attachment = platform_post[:identifier].select { |att| att['blob_signed_id'] == k }
          i = platform_post[:identifier].index { |x| attachment.include?(x) }
          method = "rooms/#{platform_post[:identifier][i]['room_id']}/redact/#{platform_post[:identifier][i]['event_id']}"
          data = { reason: "Delete post ##{platform_post.post_id}" }
          Matrix.post(server, matrix_token, method, data)
          deleted_indexes.append(i)
        end
        if deleted_indexes.any?
          new_params = platform_post[:identifier].reject.with_index { |_e, i| deleted_indexes.include? i }
          new_params.present? ? platform_post.update!(identifier: new_params) : platform_post.delete
        end
      end

    end

    # Если есть изменения и не обновился в предыдущих платформах, то обновляем тут
    if @content.length != @post.text.length
      # отсутствие контента - это content?
      content = @post.contents.where(has_attachments: false).first # first тому что matrix только 1 контент

      if content.present?
        content.update(text: @content)
      elsif content.nil? && !@content.empty?
        Content.create!(user: @post.user, post: @post, text: @content)
      end
    end

    text =
      if @title.present? && @content.present?
        "<b>#{@title}</b><br><br>#{@content}"
      elsif @title.present? && @content.empty?
        @post.title
      else
        @content
      end
    text = @markdown.render(text)
    text = text.replace_html_to_mx_markdown if text.present?

    platform_posts.joins(:content).where(contents: { has_attachments: false }).each do |platform_post|
      room_id = platform_post[:identifier]['room_id']
      event_id = platform_post[:identifier]['event_id']

      if platform_post.identifier.dig('options', 'onlylink') # not array
        edit_mx_onlylink_post(platform_post, room_id, event_id)
        next
      end

      matrix_token = platform_post.channel.token
      server = platform_post.channel.options['server']
      method = "rooms/#{room_id}/send/m.room.message"
      data = {
        msgtype: 'm.text',
        format: 'org.matrix.custom.html',
        body: text,
        formatted_body: text,
        'm.new_content': {
          msgtype: 'm.text',
          format: 'org.matrix.custom.html',
          body: text,
          formatted_body: text
        },
        'm.relates_to': {
          event_id: event_id,
          rel_type: 'm.replace'
        }
      }
      Matrix.post(server, matrix_token, method, data)
    end

    # Fix if has telegram post && attachments has caption && update from nil to text, send msg
    fix_content = platform_posts.joins(:content).where(contents: { has_attachments: false }).none?

    if fix_content # Постим недостающее сообщение с текстом
      channel_ids =
        @post.user.channels.where(platform: Platform.find_by(title: 'matrix')).map do |channel|
          { id: channel.id, room: channel.room, token: channel.token, server: channel.options['server'] }
        end
      channel_ids.each do |channel|
        method = "rooms/#{channel[:room]}/send/m.room.message"
        data = {
          msgtype: 'm.text',
          format: 'org.matrix.custom.html',
          body: text,
          formatted_body: text
        }
        msg = Matrix.post(channel[:server], channel[:token], method, data)
        identifier = { event_id: JSON.parse(msg)['event_id'], room_id: channel[:room] }
        PlatformPost.create!(identifier: identifier, platform: Platform.find_by(title: 'matrix'), post: @post,
                             content: @post.contents.where(has_attachments: false).first, channel_id: channel[:id])
      end
      # elsif fix_content && @title.empty? && @content.empty? # Delete if text not present
      # platform_posts.joins(:content).where(contents: { has_attachments: false }).each do |platform_post|
      # method = "rooms/#{platform_post[:identifier]["room_id"]}/redact/#{platform_post[:identifier]["event_id"]}"
      # data = { reason: "Delete post ##{platform_post.post_id}" }
      # Matrix.post(matrix_token, method, data)
      # platform_post.delete
      # end
    end

    unless need_delete_attachments && @deleted_attachments.present? &&
           @attachments_count == (@post.content_attachments&.count || 0)
      return
    end

    @deleted_attachments.each do |attachment|
      blob_id = ActiveStorage::Blob.find_signed(attachment[0])&.id # may deleted in tg update
      @post.content_attachments.find_by(blob_id: blob_id).purge if blob_id.present? && attachment[1] == '0'
    end
  end

  def edit_mx_onlylink_post(platform_post, room_id, event_id)
    post_link = "#{@base_url}/posts/#{@post.id}"
    full_post_link = "<a href=\"#{post_link}\">#{post_link}</a>"
    text = @post.title.present? ? "<b>#{@post.title}</b><br>#{full_post_link}" : full_post_link.to_s

    matrix_token = platform_post.channel.token
    server = platform_post.channel.options['server']
    method = "rooms/#{room_id}/send/m.room.message"
    data = {
      msgtype: 'm.text',
      format: 'org.matrix.custom.html',
      body: text,
      formatted_body: text,
      'm.new_content': {
        msgtype: 'm.text',
        format: 'org.matrix.custom.html',
        body: text,
        formatted_body: text
      },
      'm.relates_to': {
        event_id: event_id,
        rel_type: 'm.replace'
      }
    }
    Matrix.post(server, matrix_token, method, data)
  end
end
