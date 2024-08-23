# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SendPostToPlatforms, type: :service do
  subject(:service) { described_class.new(post, "http://localhost:3080", params) }

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
        expect(post.reload.attachments).to eq(nil)
      end

      it 'post has no platform posts' do
        subject
        expect(post.reload.platform_posts.count).to eq(0)
      end
    end
  end
end
