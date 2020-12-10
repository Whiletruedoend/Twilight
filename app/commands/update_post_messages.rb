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
  end

=begin
  def make_checks(platform_posts)
    platform_posts.each_with_index do |platform_post, index|
      begin
        # no more posts to delete
        if @text_operations["final_end"].present?
          @text_operations = {}
          break
        end

        if @text_operations["end"].present?
          puts("ENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDENDEND")
          if platform_post[index+1].present? # remove next post cuz updated contents < contents before update
            puts("WE NEED DELETE NEXT MESSAGE!!!!")
            #Telegram.bot.delete_message(chat_id: platform_post[index+1][:identifier]["chat_id"], message_id: platform_post[index+1][:identifier]["message_id"])
            @removed_posts.append(platform_post)
            @text_operations.clear
            @text_operations.merge!(end: true)
            break
          else # after N iterations this is the last post
            puts("WE DO NOT NEED TO DELETE NEXT MESSAGE!!!!")
            @text_operations = {}
            @text_operations.merge!(final_end: true)
            break
          end
        end

        if @text_operations["move_text_next_post"].present?
          puts("MOVE NEXT PRESENT")
          @text_operations = {}
          @text = @text_operations[:move_text_next_post]
        end

        if @length >= 4096 || @text_operations["move_text_next_post"].present?
          @only_one_post = false
          clear_text = @text_operations["move_text_next_post"].present? ? 0 : @title.length + 9
          platform_post.content.update(text: @text[clear_text...4096])
          Telegram.bot.edit_message_text({ chat_id: platform_post[:identifier]["chat_id"], message_id: platform_post[:identifier]["message_id"], text: @text[clear_text...4096] })
          @text[0...4096] = ""
          @length -= 4096
          @text_operations.merge!(move_text_next_post: @text) if @length > 0
          puts("LEGTH >= 4096")

          if platform_post[index+1].present?
            puts("MOVE NEXT")
            next # We don't need create new platform post
          else # new contents > platform posts, make additional messages!
            puts("CREATE NEW SOMETHING")
            content = Content.create!(user: @post.user, post: @post, text: @text)
            other_channels = PlatformPost.where(content: platform_post.content, platform: Platform.find_by_title("telegram"), post: @post )
            other_channels.each do |channel|
              msg = Telegram.bot.send_message({ chat_id: channel[:identifier]["chat_id"], text: @text, parse_mode: "html" })
              PlatformPost.create!(identifier: { chat_id: msg["result"]["chat"]["id"], message_id: msg["result"]["message_id"] }, platform: Platform.find_by_title("telegram"), post: @post, content: content)
            end
            next
          end
        else # len < 4096, no need add new contents, but may remove
          if @text.present? # if 2 contents --> 1 content, 2nd content is empty
            puts("LEGTH <= 4096")
            clear_text = @only_one_post ? 0 : @title.length + 9
            other_channels = PlatformPost.where(content: platform_post.content, platform: Platform.find_by_title("telegram"), post: @post )
            other_channels.each do |channel|
              #puts(text[clear_text...4096])
              puts("EDIT MESSAGE FROM CHANNEL: #{channel[:identifier]["chat_id"]}")
              Telegram.bot.edit_message_text({ chat_id: channel[:identifier]["chat_id"], message_id: channel[:identifier]["message_id"], text: @text[clear_text...4096], parse_mode: "html" })
            end
            clear_text = @only_one_post ? @title.length + 9 : 0 # it's not mistake!
            platform_post.content.update(text: @text[clear_text...4096])
            @text_operations.merge!(end: true)
            puts("MERGED END, WHO IS NEXT?")
            @text[0...4096] = ""
          end
        end

        # for first time
        if @text_operations["end"].present?
          puts("ITS REALLY END????")
          # 1 updated post, but contents > posts
          if platform_post[index+1].present?
            puts("NEXT PLATFORM EXISTS")
            #Telegram.bot.delete_message(chat_id: platform_post[index+1][:identifier]["chat_id"], message_id: platform_post[index+1][:identifier]["message_id"])
            @removed_posts.append(platform_post)
            @text_operations = {}
            @text_operations.merge!(end: true)
          else
            puts("NEXT PLATFORM NOT FOUND!")
            # 1 updated post = 1 content
            @text_operations.merge!(final_end: true)
            # end
          end
        end
        puts("MAY REPEAT BLOCK?")
      end
    end
  end
=end

  def make_checks(platform_posts)
    edited_content_id = nil # don't delete him

    platform_posts.each_with_index do |platform_post, index |
      if @length >= 4096 #|| @text_operations[:move_text_next_post].present?
        # todo
      else # len < 4096, no need add new contents, but may remove
        if @text.present? # if N contents --> N-1 content and content not empty
          edited_content_id = platform_post.content.id
          clear_text = @only_one_post ? 0 : @title.length + 9
          other_channels = PlatformPost.where(content: platform_post.content, platform: Platform.find_by_title("telegram"), post: @post )
          other_channels.each { |channel|  Telegram.bot.edit_message_text({ chat_id: channel[:identifier]["chat_id"], message_id: channel[:identifier]["message_id"], text: @text[clear_text...4096], parse_mode: "html" }) }
          clear_text = @only_one_post ? @title.length + 9 : 0 # it's not mistake!
          platform_post.content.update(text: @text[clear_text...4096])
          @text[0...4096] = ""
        else # if N contents --> N-1 content and content is empty (trash)
          other_channels = PlatformPost.where(content: platform_post.content, platform: Platform.find_by_title("telegram"), post: @post )
          other_channels.each do |channel|
            next if edited_content_id.present? && (channel.content&.id == edited_content_id)
            Telegram.bot.delete_message({ chat_id: channel[:identifier]["chat_id"], message_id: channel[:identifier]["message_id"] })
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
