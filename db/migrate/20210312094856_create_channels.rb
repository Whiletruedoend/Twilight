# frozen_string_literal: true

class CreateChannels < ActiveRecord::Migration[6.1]
  def up
    create_table :channels do |t|
      t.belongs_to :platform
      t.belongs_to :user
      t.boolean :enabled
      t.string :token
      t.string :room
      t.json :options
      t.timestamps
    end
    add_column :platform_posts, :channel_id, :bigint
    add_index :platform_posts, :channel_id
  end

  def down
    remove_index :platform_posts, :channel_id
    remove_column :platform_posts, :channel_id
    drop_table :channels
  end
end
