class Post < ApplicationRecord
  #validates :title, presence: true
  belongs_to :user

  has_many :contents
  has_many :comments
  has_many :platform_posts
  has_and_belongs_to_many :tags, class_name: 'Tag', join_table: "item_tags", :as => :item, foreign_key: "item_id", :dependent => :delete_all
  has_many :active_tags, -> { active("Post") }, class_name: 'ItemTag', foreign_key: "item_id"

  self.per_page = 5

  def active_tags_names
    self.active_tags.map { |s| s.tag.name }
  end

  def get_content
    text = ""
    self.contents.each do |msg|
      text += msg[:text] if msg[:text].present?
    end
    text
  end

  def get_content_attachments
    Content.where(post: self).map{ |c| c.attachments }&.first
  end
end