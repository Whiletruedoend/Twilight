class RenameAccessToPrivacy < ActiveRecord::Migration[6.1]
  def up
    rename_column :posts, :access, :privacy
    change_column_default :posts, :privacy, 0
  end
  def down
    change_column_default :posts, :privacy, nil
    rename_column :posts, :privacy, :access
  end
end
