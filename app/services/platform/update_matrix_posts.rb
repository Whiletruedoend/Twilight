# frozen_string_literal: true

class Platform::UpdateMatrixPosts
  prepend SimpleCommand

  attr_accessor :post, :params

  def initialize(post, base_url, params)
    @params = params
    @post = post
    @base_url = base_url

    @title = post.title
    @text = params[:post][:content]
    @deleted_attachments = @params[:deleted_attachments]
    @attachments_count = @post.attachments.count || 0

    @platform = Platform.find_by(title: 'matrix')

    @markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, no_intra_emphasis: false, fenced_code_blocks: false,
                                                                 disable_indented_code_blocks: true, autolink: false,
                                                                 tables: false, underline: false, highlight: false)
  end

  def call
    platform_posts = @post.platform_posts.where(platform: Platform.where(title: 'matrix'))

    platform_posts.joins(:content).where(contents: { has_attachments: true }).each do |platform_post|
      if platform_post.identifier.is_a?(Hash) && platform_post.identifier.dig('options', 'onlylink')
        room_id = platform_post[:identifier]['room_id']
        event_id = platform_post[:identifier]['event_id']
        edit_mx_onlylink_post(platform_post, room_id, event_id)
        next
      end
    end

    delete_attachments(platform_posts) if @deleted_attachments.present?

    text = @markdown.render(@post.text)
    text = text.replace_html_to_mx_markdown if text.present?
    text.delete_suffix!("<br>")
    send_text = @post.title.present? ? "<b>#{@post.title}</b><br><br>#{text}" : text.to_s

    text_content = @post.contents.find{ |c| c.platform == @platform && !c.has_attachments }
    if text_content.nil?
      Content.create!(user: @post.user, post: @post, text: text,
                      has_attachments: true, platform: @platform)
    else
      text_content.update!(text: text)
    end

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
        body: send_text,
        formatted_body: send_text,
        'm.new_content': {
          msgtype: 'm.text',
          format: 'org.matrix.custom.html',
          body: send_text,
          formatted_body: send_text
        },
        'm.relates_to': {
          event_id: event_id,
          rel_type: 'm.replace'
        }
      }
      Matrix.post(server, matrix_token, method, data)
    end
  end

  def delete_attachments(platform_posts)
    attachments = @deleted_attachments.to_unsafe_h
    del_att = attachments.select { |val| attachments[val] == '0' }

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

  def edit_mx_onlylink_post(platform_post, room_id, event_id)
    post_link = "#{@base_url}/posts/#{@post.slug_url}"
    full_post_link = "<a href=\"#{post_link}\">#{post_link}</a>"
    text = @post.title.present? ? "<b>#{@post.title}</b><br><br>#{full_post_link}" : full_post_link.to_s
    text.delete_suffix!("<br>")

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
