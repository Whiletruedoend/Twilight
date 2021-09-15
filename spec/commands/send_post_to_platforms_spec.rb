# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SendPostToPlatforms, type: :service do
  subject(:service) { described_class.new(post, params) }

  let(:post) { create(:post, title: 'Post title') }
  let(:params) do
    ActionController::Parameters.new(post: { title: 'A',
                                             content: 'B',
                                             attachments: [] })
  end

  let(:bot) { Telegram::Bot::ClientStub.new('1234567890:ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890') }

  describe '.initialize' do
    it { expect { service }.not_to raise_error }
  end

  describe '#call' do
    subject { service.call }

    it { expect { service }.not_to raise_error }

    context 'when create post only for site' do
      let(:params) do
        { post: { title: 'Post title',
                  content: 'Lorem Ipsum',
                  attachments: [] } }
      end

      it 'post has title' do
        subject
        expect(post.reload.title).to eq('Post title')
      end

      it 'post has text' do
        subject
        expect(post.reload.text).to eq('Lorem Ipsum')
      end

      it 'post has no attachments' do
        subject
        expect(post.reload.content_attachments).to eq(nil)
      end

      it 'post has no platform posts' do
        subject
        expect(post.reload.platform_posts.count).to eq(0)
      end
    end

    context 'when create post for telegram' do
      before do
        Telegram.bots_config = { '-1001234567890': bot.token }
        Telegram.bots.merge!('-1001234567890': bot)
      end
      let!(:tg_channel) do
        create(:channel, platform: Platform.first, enabled: true, token: bot.token,
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
          it 'post full text to telegram' do
            text = "<b>#{params[:post][:title]}</b>\n\n#{params[:post][:content]}\n"
            expect(subject.instance_values['msg']).to eq([{ chat_id: '-1001234567890',
                                                            text: text,
                                                            parse_mode: 'html',
                                                            disable_notification: true }])
          end
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
          it 'decrease first telegram block' do
            title_length = "<b>#{params[:post][:title]}</b>\n\n\n".length
            text = "<b>#{params[:post][:title]}</b>\n\n#{params[:post][:content][0..(4096 - title_length)]}\n"
            expect(subject.instance_values['msg']).to eq([{ chat_id: '-1001234567890',
                                                            text: text,
                                                            parse_mode: 'html',
                                                            disable_notification: true }])
          end
        end
      end
      # context 'when post has attachments' do
      #
      # end
    end
    # context 'when create post for matrix' do
    #
    # end
    # context 'when create post for telegram & matrix' do
    #
    # end
  end
end
