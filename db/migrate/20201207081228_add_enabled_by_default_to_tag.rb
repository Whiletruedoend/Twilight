# frozen_string_literal: true

class AddEnabledByDefaultToTag < ActiveRecord::Migration[6.0]
  def up
    add_column :tags, :enabled_by_default, :boolean
  end

  def down
    remove_column :tags, :enabled_by_default, :boolean
  end
end
