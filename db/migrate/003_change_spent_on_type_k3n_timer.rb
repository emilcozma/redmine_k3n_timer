class ChangeSpentOnTypeK3nTimer < ActiveRecord::Migration
  def self.up
    change_column :k3n_timers, :spent_on, :date
  end

  def self.down
    # no-op
  end
end
