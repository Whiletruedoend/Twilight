class AddAccessLevelToUser < ActiveRecord::Migration[6.0]
  def up
    remove_column :users, :name
    remove_column :users, :avatar
    add_column :users, :access_level, :integer, default: 2

    change_column :users, :rss_token, :string, :unique => true, :null => false
  end
  def down
    add_column :users, :name, :string
    add_column :users, :avatar, :string
    remove_column :users, :access_level
  end
end