class Tag < ApplicationRecord
  has_and_belongs_to_many :item_tags, class_name: 'User', join_table: "user_tags"

  validates :name, presence: true, uniqueness: true
end