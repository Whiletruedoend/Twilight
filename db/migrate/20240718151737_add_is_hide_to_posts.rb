class AddIsHideToPosts < ActiveRecord::Migration[7.0]
  def up
    add_column :posts, :is_hide, :boolean, default: false
    add_column :posts, :uuid, :uuid, null: false, unique: true
  end
  def down
    remove_column :posts, :is_hide, :boolean
    remove_column :posts, :uuid, :uuid
  end
end
