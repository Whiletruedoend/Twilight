class RemoveAccessLevelFromUser < ActiveRecord::Migration[6.1]
  def up
    remove_column :users, :access_level
  end

  def down
    add_column :users, :access_level, :integer, default: 2
  end
end
