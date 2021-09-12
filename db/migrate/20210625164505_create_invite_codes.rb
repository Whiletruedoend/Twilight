# frozen_string_literal: true

class CreateInviteCodes < ActiveRecord::Migration[6.1]
  def up
    create_table :invite_codes do |t|
      t.belongs_to :user
      t.string :code
      t.boolean :is_enabled
      t.boolean :is_single_use
      t.integer :usages, default: 0
      t.integer :max_usages
      t.datetime :expires_at
      t.timestamps
    end
  end

  def down
    drop_table :invite_codes
  end
end
