class ItemTag < ApplicationRecord
  extend Enumerize

  belongs_to :tag
  belongs_to :item, polymorphic: true

  enumerize :item_type, in: [ "User", "Post" ], scope: :having_type

  scope :active, ->(model_name) { where(item_type: model_name, enabled: true) }
end

