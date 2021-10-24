# frozen_string_literal: true

class Tag < ApplicationRecord
  include RailsSortable::Model
  set_sortable :sort  # Indicate a sort column

  has_many :item_tags

  validates :name, presence: true, uniqueness: true
end
