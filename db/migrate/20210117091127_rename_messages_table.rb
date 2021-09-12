# frozen_string_literal: true

class RenameMessagesTable < ActiveRecord::Migration[6.1]
  def up
    rename_table :messages, :contents
    remove_column :contents, :type
    create_table :platform_users do |t|
      t.json :identifier
      t.belongs_to :platform
    end
    create_table :comments do |t|
      t.string :text
      t.json :identifier
      t.belongs_to :post
      t.belongs_to :user
      t.belongs_to :platform_user
      t.boolean 'has_attachments', default: false
      t.boolean 'is_edited', default: false
      t.timestamps
    end
  end

  def down
    rename_table :contents, :messages
    add_column :messages, :type, :string
    drop_table :comments
    drop_table :platform_users
  end
end
