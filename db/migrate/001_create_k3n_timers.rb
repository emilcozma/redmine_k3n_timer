# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class CreateK3nTimers < ActiveRecord::Migration

  def self.up
    
    create_table :k3n_timers, :force => true do |t|
      t.column :spent_on, :timestamp
	  t.column :hours,       :float,    :null => false
      t.column :comments,    :string,   :limit => 255
	  t.column :user_id, :integer, :default => 0, :null => false
      t.column :created_on, :timestamp
	  t.column :updated_on, :timestamp
    end

    add_index :k3n_timers, :spent_on
  end

  def self.down
    drop_table :k3n_timers
  end
end
