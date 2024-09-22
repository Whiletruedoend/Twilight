# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Post, type: :model do
  subject(:post) { create(:post) }
  let!(:telegram) { create(:platform, title: 'telegram') }
  let!(:matrix) { create(:platform, title: 'matrix') }

  it { is_expected.to be_valid }

  describe '#platforms' do
    context 'when post has no platforms' do
      it { expect(subject.platforms).to eq({ 'matrix' => false, 'telegram' => false }) }
    end
    context 'when post has telegram platform' do
      let!(:platform_post) { create(:platform_post, post: post, platform: telegram) }
      it { expect(subject.platforms).to include('telegram' => true) }
    end
    context 'when post has matrix platform' do
      let!(:platform_post) { create(:platform_post, post: post, platform: matrix) }
      it { expect(subject.platforms).to include('matrix' => true) }
    end
    context 'when post has telegram and matrix platform' do
      let!(:platform_post_t) { create(:platform_post, post: post, platform: telegram) }
      let!(:platform_post_m) { create(:platform_post, post: post, platform: matrix) }
      it { expect(subject.platforms).to include('telegram' => true, 'matrix' => true) }
    end
  end

  describe '#text' do
    context 'when post has no contents' do
      it { expect(subject.text).to eq('') }
    end

    context 'when post has 1 content' do
      let!(:content) { create(:content, post: post) }
      it { expect(subject.text).to eq(content.text) }
    end

    context 'when post has 2 contents' do
      let!(:content1) { create(:content, post: post) }
      let!(:content2) { create(:content, post: post) }
      it { expect(subject.text).to eq(content1.text + content2.text) }
    end
  end

  #describe '#content_attachments' do
  #  context 'when content has no attachments' do
  #    let!(:content) { create(:content, post: post) }
  #    it { expect(subject.content_attachments).to eq(nil) }
  #  end

  #  context 'when content has attachments' do
  #    let!(:content_with_att) { create(:content, :with_attachment, post: post) }
  #    it { expect(subject.content_attachments.attachments.last).to eq(content_with_att.attachments.last) } # wtf
  #  end
  #end

  # describe '#get_posts' do
  # end
end
