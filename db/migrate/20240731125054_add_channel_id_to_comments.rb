class AddChannelIdToComments < ActiveRecord::Migration[7.0]
  def up
    add_belongs_to :comments, :channel
    add_belongs_to :comments, :platform
  end
  
  def down
    remove_belongs_to :comments, :channel
    remove_belongs_to :comments, :platform
  end
end
