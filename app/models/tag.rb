class Tag < ApplicationRecord
  include RailsSortable::Model
  set_sortable :sort  # Indicate a sort column

  has_and_belongs_to_many :item_tags, class_name: 'User', join_table: "user_tags"

  validates :name, presence: true, uniqueness: true
end