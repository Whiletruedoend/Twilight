class AddUpload < ActiveRecord::Migration[7.0]
  def change
    create_table :uploads do |t|
      t.uuid :uuid
      t.integer :privacy, default: 0
      t.references :user
      t.string :slug
      t.string :path

      t.timestamps
    end
  end
end
