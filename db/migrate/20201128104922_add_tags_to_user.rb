# frozen_string_literal: true

class AddTagsToUser < ActiveRecord::Migration[6.0]
  def up
    create_table :tags do |t|
      t.string :name
    end
    create_table :item_tags do |t|
      t.boolean :enabled, default: true
      t.belongs_to :tag
      t.references :item, polymorphic: true
    end
  end

  def down
    drop_table :tags
    drop_table :item_tags
  end
end
