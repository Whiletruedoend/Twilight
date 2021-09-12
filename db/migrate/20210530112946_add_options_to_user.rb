# frozen_string_literal: true

class AddOptionsToUser < ActiveRecord::Migration[6.1]
  def up
    add_column :users, :options, :json, default: {}
  end

  def down
    remove_column :users, :options
  end
end
