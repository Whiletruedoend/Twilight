class CreatePlatformPosts < ActiveRecord::Migration[6.0]
  def up
    create_table :platform_posts do |t|
      t.string :Identifier
      t.timestamps
    end
  end
  def down
    drop_table :platform_posts
  end
end
