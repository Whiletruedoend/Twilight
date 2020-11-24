class CreateUsers < ActiveRecord::Migration[6.0]
  def up
    create_table :users do |t|
      t.string :login
      t.index :login, unique: true
      t.string :name
      t.string :avatar
      t.string :rss_token
      t.boolean :is_admin

      t.string    :crypted_password
      t.string    :password_salt

      t.string    :persistence_token
      t.index     :persistence_token, unique: true

      t.timestamps
    end
  end
  def down
    drop_table :users
  end
end
