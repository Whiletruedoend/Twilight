# frozen_string_literal: true

class ChangePlatformPosts < ActiveRecord::Migration[6.0]
  def up
    remove_column :platform_posts, :identifier
    add_column :platform_posts, :identifier, :json
  end

  def down
    remove_column :platform_posts, :identifier
    add_column :platform_posts, :identifier, :string
  end
end
