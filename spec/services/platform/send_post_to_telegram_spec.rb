# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Platform::SendPostToTelegram, type: :service do
  subject(:service) { described_class.new(post, params, channel_ids) }
  let(:platform) { create(:platform, title: 'Telegram') }

  let(:post) { create(:post, title: 'Post title') }
  let(:params) do
    ActionController::Parameters.new(post: { title: 'A',
                                             content: 'B',
                                             attachments: [] })
  end

  let(:bot) { Telegram::Bot::ClientStub.new('1234567890:ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890') }

  before do
    Telegram.bots_config = { '-1001234567890': bot.token }
    Telegram.bots.merge!('-1001234567890': bot)
  end

  let(:channel_ids) { tg_channel.id.to_s }
  let(:tg_channel) do
    create(:channel, platform: platform, enabled: true, token: bot.token,
                     room: '-1001234567890',
                     options: { 'id' => bot.token.split(':')[0],
                                'room_attachments' => '123456789',
                                'author' => '987654321',
                                'notifications_enabled' => false,
                                'comments_enabled' => false,
                                'title' => 'Channel title',
                                'username' => nil,
                                'avatar_size' => 0 })
  end

  describe '.initialize' do
    it { expect { service }.not_to raise_error }
  end

  describe '#call' do
    subject { service.call }

    it { expect { service }.not_to raise_error }

    context 'when post has no attachments' do
      context 'when post length < 4096 symbols' do
        let(:params) do
          ActionController::Parameters.new(post: { title: 'Post title',
                                                   content: 'Lorem Ipsum',
                                                   attachments: [] },
                                           channels: { tg_channel.id.to_s => '1' },
                                           options: { 'enable_notifications_1' => '0',
                                                      'onlylink_1' => '0',
                                                      'caption_1' => '0' })
        end
        # it 'post full text to telegram' do
        #  text = "<b>#{params[:post][:title]}</b>\n\n#{params[:post][:content]}\n"
        #  expect(subject.instance_values['msg']).to eq([{ chat_id: '-1001234567890',
        #                                                  text: text,
        #                                                  parse_mode: 'html',
        #                                                  disable_notification: true }])
        # end
      end
      context 'when post length > 4096 symbols' do
        let(:params) do
          ActionController::Parameters.new(post: { title: 'Post title',
                                                   content: ('AA' * 2049),
                                                   attachments: [] },
                                           channels: { tg_channel.id.to_s => '1' },
                                           options: { 'enable_notifications_1' => '0',
                                                      'onlylink_1' => '0',
                                                      'caption_1' => '0' })
        end
        # it 'decrease first telegram block' do
        #  title_length = "<b>#{params[:post][:title]}</b>\n\n\n".length
        #  text = "<b>#{params[:post][:title]}</b>\n\n#{params[:post][:content][0..(4096 - title_length)]}\n"
        #  expect(subject.instance_values['msg']).to eq([{ chat_id: '-1001234567890',
        #                                                  text: text,
        #                                                  parse_mode: 'html',
        #                                                  disable_notification: true }])
        # end
      end
    end
    # context 'when post has attachments' do
    # end
    # context 'when create post for telegram & matrix' do
    # end
  end

  # describe "#upload_to_telegram" do
  #  subject { service.upload_to_telegram(bot, room_attachments, content) }

  #  let(:room_attachments) { '-1001234567890' }
  #  let(:content) { create(:content) }

  #  context 'when attachment is image' do
  #    before do
  #      content.attachments.attach(io: File.open(Rails.root.join('spec', 'support', 'image.jpg')),
  #                                 filename: 'image.jpg', content_type: 'image/jpg')
  #    end

  # it 'uploads to telegram' do
  # subject.instance_values['msg'].to eq([{ chat_id: '-1001234567890' }])
  # end
  #  end
  # end
end
