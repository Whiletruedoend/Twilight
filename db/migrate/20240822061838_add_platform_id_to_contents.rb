class AddPlatformIdToContents < ActiveRecord::Migration[7.0]
  def up
    add_reference :contents, :platform
  end

  def down
    remove_reference :contents, :platform
  end
end
