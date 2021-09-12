# frozen_string_literal: true

class CreatePlatforms < ActiveRecord::Migration[6.0]
  def up
    create_table :platforms do |t|
      t.string :title
    end
    add_reference :platform_posts, :platform, foreign_key: true
  end

  def down
    remove_reference :platform_posts, :platform, foreign_key: true
    drop_table :platforms
  end
end
