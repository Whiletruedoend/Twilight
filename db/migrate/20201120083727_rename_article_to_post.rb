class RenameArticleToPost < ActiveRecord::Migration[6.0]
  def up
    rename_table :articles, :posts
  end
  def down
    rename_table :posts, :articles
  end
end