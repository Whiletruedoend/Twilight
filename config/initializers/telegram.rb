Rails.application.config.after_initialize do
  tokens = Channel.all.where(platform: Platform.find_by(title: 'telegram'), enabled: true).map do |channel|
    [channel.options['bot_id'].to_s, channel.token]
  end.to_h
    
  Telegram.bots_config = tokens # runs from config.ru
end
