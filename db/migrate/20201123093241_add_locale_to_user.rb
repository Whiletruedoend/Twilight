# frozen_string_literal: true

class AddLocaleToUser < ActiveRecord::Migration[6.0]
  def up
    add_column :users, :locale, :string
  end

  def down
    remove_column :users, :locale, :string
  end
end
