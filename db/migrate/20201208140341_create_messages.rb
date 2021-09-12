# frozen_string_literal: true

class CreateMessages < ActiveRecord::Migration[6.0]
  def up
    create_table :messages do |t|
      t.string :type
      t.string :text
      t.belongs_to :post
      t.belongs_to :user
    end
    remove_column :posts, :content
    add_belongs_to :platform_posts, :content
  end

  def down
    remove_belongs_to :platform_posts, :content
    drop_table :messages
    add_column :posts, :content, :string
  end
end
