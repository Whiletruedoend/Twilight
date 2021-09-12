# frozen_string_literal: true

class CreateCategories < ActiveRecord::Migration[6.1]
  def up
    create_table :categories do |t|
      t.belongs_to :user
      t.string :name
      t.string :color
      t.integer :sort
      t.timestamps
    end
    add_reference :posts, :category
    add_foreign_key :posts, :categories, on_delete: :nullify
    add_column :tags, :sort, :integer
  end

  def down
    remove_reference :posts, :category, foreign_key: true
    drop_table :categories
    remove_column :tags, :sort
  end
end
