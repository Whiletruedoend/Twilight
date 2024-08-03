class AddReplyIdToComments < ActiveRecord::Migration[7.0]
  def up
    add_reference :comments, :reply, index: true
  end
  def down
    remove_reference :comments, :reply, index: true
  end
end
