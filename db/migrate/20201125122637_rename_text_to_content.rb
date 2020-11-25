class RenameTextToContent < ActiveRecord::Migration[6.0]
  def up
    rename_column :posts, :text, :content
    add_column :posts, :user_id, :bigint
    add_index :posts, :user_id
  end
  def down
    remove_index :posts, :user_id
    rename_column :posts, :content, :text
  end
end
