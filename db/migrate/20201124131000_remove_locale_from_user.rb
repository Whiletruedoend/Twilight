class RemoveLocaleFromUser < ActiveRecord::Migration[6.0]
  # Because not REST-friendly
  def up
    remove_column :users, :locale
  end
  def down
    add_column :users, :locale, :string
  end
end