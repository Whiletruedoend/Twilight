class Category < ApplicationRecord
  include RailsSortable::Model
  set_sortable :sort  # Indicate a sort column

  belongs_to :user
  has_many :posts, dependent: :nullify
end