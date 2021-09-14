# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  subject(:user) { create(:user) }

  it { is_expected.to be_valid }

  describe '#generate_rss' do
    before { subject.generate_rss }

    it { expect(subject.rss_token.length).to eq(32) }
  end
end
