class ChangePlatformPosts < ActiveRecord::Migration[6.0]
  def up
    change_column :platform_posts, :identifier, :json
  end
  def down
    change_column :platform_posts, :identifier, :string
  end
end