class AddChannelIdToComments < ActiveRecord::Migration[7.0]
  def up
    add_belongs_to :comments, :channel
  end
  
  def down
    remove_belongs_to :comments, :channel
  end
end
