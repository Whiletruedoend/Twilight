class AddPostIdToPosts < ActiveRecord::Migration[6.0]
  def up
    add_column :platform_posts, :post_id, :bigint
    add_index :platform_posts, :post_id
    rename_column :platform_posts, :Identifier, :identifier
  end

  def down
    remove_index :platform_posts, :post_id
    remove_column :platform_posts, :post_id
    rename_column :platform_posts, :identifier, :Identifier
  end
end
