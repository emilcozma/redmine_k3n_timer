class AddUsersK3nTimer < ActiveRecord::Migration
  def self.up
    add_column :users, :k3n_timer, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :users, :k3n_timer
  end
end
