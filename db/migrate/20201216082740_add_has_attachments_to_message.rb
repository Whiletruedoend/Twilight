class AddHasAttachmentsToMessage < ActiveRecord::Migration[6.0]
  def up
    add_column :messages, :has_attachments, :boolean, default: false
  end
  def down
    remove_column :messages, :has_attachments
  end
end
