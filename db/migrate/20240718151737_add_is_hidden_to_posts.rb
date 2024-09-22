class AddIsHiddenToPosts < ActiveRecord::Migration[7.0]
  def up
    add_column :posts, :is_hidden, :boolean, default: false
    add_column :posts, :uuid, :uuid
    Post.update_all(uuid: SecureRandom.uuid)
  end
  def down
    remove_column :posts, :is_hidden, :boolean
    remove_column :posts, :uuid, :uuid
  end
end
