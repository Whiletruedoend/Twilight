class UpdatePostMessages
  prepend SimpleCommand

  attr_accessor :post, :params

  def initialize(post, params)
    @params = params
    @post = post

    @title = post.title
    @content = params[:post][:content]
    @text = "<b>#{@title}</b>\n\n#{@content}"
    @length = @text.length

    @only_one_post = true
    @next_post = false

    @markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, no_intra_emphasis: false, fenced_code_blocks: false, disable_indented_code_blocks: true, autolink: false, tables: false, underline: false, highlight: false)
  end

  # KNOWN BUG: If you add new content, title in message don't send
  def make_checks(platform_posts)
    edited_content_id = nil # don't delete him

    platform_posts.each do |platform_post|
      if @length >= 4096
        @only_one_post = false
        clear_text = @next_post ? 0 : @title.length + 9
        platform_post.content.update(text: @text[clear_text...4096])
        begin
          Telegram.bot.edit_message_text({ chat_id: platform_post[:identifier]["chat_id"], message_id: platform_post[:identifier]["message_id"], text: @text[clear_text...4096] })
        rescue # Message don't edit (if you previous text == current text || if bot don't have access to message)
        end
        @text[0...4096] = ""
        @length -= 4096

        if platform_posts.include?(PlatformPost.find_by_id(platform_post.id+1))
          @next_post = true
          next # We don't need create new platform post
        else # new contents > platform posts, make additional messages!
          @next_post = false
          content = Content.create!(user: @post.user, post: @post, text: @text)
          other_channels = PlatformPost.where(content: platform_post.content, platform: Platform.find_by_title("telegram"), post: @post )
          other_channels.each do |channel|
            begin
              new_text = @markdown.render(@text)
              new_text = new_text.replace_html_to_tg_markdown
              msg = Telegram.bot.send_message({ chat_id: channel[:identifier]["chat_id"], text: new_text, parse_mode: "html" })
            rescue # Message don't send (if bot don't have access to message)
            end
            PlatformPost.create!(identifier: { chat_id: msg["result"]["chat"]["id"], message_id: msg["result"]["message_id"] }, platform: Platform.find_by_title("telegram"), post: @post, content: content)
          end
          next
        end

      else # len < 4096, no need add new contents, but may remove
        if @text.present? # if N contents --> N-1 content and content not empty
          edited_content_id = platform_post.content.id
          clear_text = @only_one_post ? 0 : @title.length + 9
          other_channels = PlatformPost.where(content: platform_post.content, platform: Platform.find_by_title("telegram"), post: @post )
          other_channels.each do |channel|
            begin
              new_text = @markdown.render(@text[clear_text...4096])
              new_text = new_text.replace_html_to_tg_markdown
              Telegram.bot.edit_message_text({ chat_id: channel[:identifier]["chat_id"], message_id: channel[:identifier]["message_id"], text: new_text, parse_mode: "html" })
            rescue # Message don't edit (if you previous text == current text || if bot don't have access to message)
            end
          end
          clear_text = @only_one_post ? @title.length + 9 : 0 # it's not mistake!
          platform_post.content.update(text: @text[clear_text...4096])
          @text[0...4096] = ""
        else # if N contents --> N-1 content and content is empty (trash)
          other_channels = PlatformPost.where(content: platform_post.content, platform: Platform.find_by_title("telegram"), post: @post )
          other_channels.each do |channel|
            next if edited_content_id.present? && (edited_content_id == channel.content&.id)
            begin
            Telegram.bot.delete_message({ chat_id: channel[:identifier]["chat_id"], message_id: channel[:identifier]["message_id"] })
            rescue # Message don't delete (bot don't have access to message)
            end
            channel.content.delete if channel.content.present?
            channel.delete
          end
        end
      end
    end

  end

  def update_telegram_posts(platform_posts)
    make_checks(platform_posts)
  end

  def call
    update_telegram_posts(post.platform_posts.where(platform: Platform.where(title: "telegram")))
  end
end
