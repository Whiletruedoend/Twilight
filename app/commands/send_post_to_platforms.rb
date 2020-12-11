class SendPostToPlatforms
  prepend SimpleCommand

  attr_accessor :post, :params

  def initialize(post, params)
    @params = params
    @post = post
  end

  def call
    if params[:platforms].nil? || params[:platforms].values.exclude?("1")
      Content.create!(user: @post.user, post: @post, text: params[:post][:content])
      return
    end

    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, no_intra_emphasis: false, fenced_code_blocks: false,
                                       disable_indented_code_blocks: true, autolink: false, tables: false,
                                       underline: false, highlight: false)

    params[:platforms].select{ |k,v| v == "1" }.each do |platform|
      case platform[0]
        when "telegram"
          channel_ids = Rails.configuration.credentials[:telegram][:channel_ids]
          next if channel_ids.empty?

          title = post.title
          content = params[:post][:content]#.replace_markdown_to_symbols # we need: input: html, output: markdown (in the future?)
          text = "**#{title}**\n\n#{content}"

          length = text.length
          created_messages = []

          if length >= 4096
            same_thing = false
            clear_text = title.length + 6
            while (length > 0 || same_thing) && text.present?
              t = same_thing ? text[0...4096] : text[clear_text...4096]
              created_messages.append(Content.create!(user: @post.user, post: @post, text: t))
              text[0...4096] = ""
              length -= 4096
              same_thing = true if length > 0
            end
          else
            created_messages.append(Content.create!(user: @post.user, post: @post, text: content))
          end

          channel_ids.each do |channel_id|
            first_message = true
            created_messages.each do |message|
              text = first_message ? "**#{title}**\n\n#{message[:text]}" : message[:text]
              first_message = false
              new_text = markdown.render(text)
              new_text = new_text.replace_html_to_tg_markdown
              msg = Telegram.bot.send_message({ chat_id: channel_id, text: new_text, parse_mode: "html" })
              PlatformPost.create!(identifier: { chat_id: msg["result"]["chat"]["id"], message_id: msg["result"]["message_id"] }, platform: Platform.find_by_title(platform), post: @post, content: message)
            end

          end
        else # todo: moare platforms!
          nil
      end
    end
  end
end