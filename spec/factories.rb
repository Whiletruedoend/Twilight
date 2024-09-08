# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    item { nil }
    user { nil }
    viewed { false }
    event { "none" }
    status { "notice" }
    text { nil }
  end

  factory :category do
    user
    name { Faker::Book.genre }
    color { Faker::Color.hex_color }
    sort { 0 }
  end
  factory :channel do
    user
    platform
    enabled { false }
  end
  factory :comment do
    user
    post
    platform_user
    text { Faker::Lorem.sentence }
    identifier { {} }
    is_edited { false }
  end
  factory :content do
    user
    post
    text { Faker::Lorem.paragraph }

    trait :with_attachment do
      after(:build) do |content|
        content.attachments.attach(io: File.open(Rails.root.join('spec', 'support', 'image.jpg')),
                                   filename: 'image.jpg')
      end
    end
  end
  factory :invite_code do
    user
    code { Faker::Internet.password }
    is_enabled { false }
    is_single_use { false }
    usages { 0 }
    max_usages { 0 }
    expires_at { Time.current + 1.day }
  end
  factory :item_tag do
    tag
    item
    enabled { false }
  end
  factory :platform_post do
    platform
    post
    content
    channel
    identifier { {} }
  end
  factory :platform_user do
    platform
    post
    content
    channel
    identifier { {} }
  end
  factory :platform do
    title { Faker::App.name } # telegram, matrix
  end
  factory :post do
    user
    category
    title { Faker::JapaneseMedia::StudioGhibli.movie }
    privacy { 0 }
  end
  factory :tag do
    name { Faker::Internet.username }
    enabled_by_default { false }
    sort { 0 }
  end
  factory :user do
    login { Faker::Internet.username }
    password { Faker::Internet.password }
    password_confirmation { password }
    options { { 'visible_posts_count' => '30', 'theme' => 'default_theme' } }
  end
end
