class Post < ApplicationRecord
  validates :title, :content, presence: true
  belongs_to :user
  has_many :platform_posts
  has_and_belongs_to_many :tags, class_name: 'Tag', join_table: "item_tags", :as => :itemable, foreign_key: "item_id", :dependent => :delete_all
  has_many :active_tags, -> { active("Post") }, class_name: 'ItemTag', foreign_key: "item_id"

  def active_tags_names
    self.active_tags.map { |s| s.tag.name }
  end
end