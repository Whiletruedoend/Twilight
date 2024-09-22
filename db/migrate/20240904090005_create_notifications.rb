class CreateNotifications < ActiveRecord::Migration[7.0]
  def change
    create_table :notifications do |t|
      t.references :item, polymorphic: true
      t.references :user, null: false, foreign_key: true
      t.boolean :viewed, null: false, default: false
      t.string :event
      t.string :status
      t.string :text

      t.timestamps
    end
  end
end
