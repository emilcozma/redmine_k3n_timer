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

class K3nTimer < ActiveRecord::Base
  include Redmine::SafeAttributes
  belongs_to :user, :class_name => 'User'
  #has_many :comments, lambda {order("created_on")}, :as => :commented, :dependent => :delete_all

  validates_presence_of :hours, :spent_on
  validates_numericality_of :hours, :allow_nil => true, :message => :invalid
  validates_length_of :comments, :maximum => 1024, :allow_nil => true
  validates :spent_on, :date => true

  attr_readonly :id

  acts_as_attachable :edit_permission => :manage_k3n_timer,
                     :delete_permission => :manage_k3n_timer
  acts_as_searchable :columns => ['spent_on', 'hours']
  acts_as_event :url => Proc.new {|o| {:controller => 'k3n_timer', :action => 'show', :id => o.id}}
  acts_as_activity_provider :scope => preload(:user),
                            :author_key => :user_id

  scope :visible, lambda {}

  scope :editable, lambda {}

  safe_attributes 'hours', 'comments', 'spent_on'

  def safe_attributes=(attrs, user=User.current)
    if attrs
      attrs = super(attrs)
    end
    attrs
  end

  def visible?(user=User.current)
    !user.nil?
  end

  def editable?(user=User.current)
    !user.nil?
  end

  def removeable?(user=User.current)
    !user.nil? && user.allowed_to?(:delete_files_k3n_timer)
  end

  # Returns true if the k3n_timer can be commented by user
  def commentable?(user=User.current)
    user.allowed_to?(:comment_k3n_timer)
  end

  def notified_users
    User.current.allowed_to?(:view_k3n_timer)
  end

  def recipients
    notified_users.map(&:mail)
  end

  # Returns the users that should be cc'd when a new k3n_timer is added
  def notified_watchers_for_added_k3n_timer
    watchers = []
    watchers
  end

  # Returns the email addresses that should be cc'd when a new k3n_timer is added
  def cc_for_added_k3n_timer
    notified_watchers_for_added_k3n_timer.map(&:mail)
  end

  # returns latest k3n_timer for projects visible by user
  def self.latest(user = User.current, count = 5)
    visible(user).preload(:user).order("#{K3n_timer.table_name}.created_on DESC").limit(count).to_a
  end

  def validate_time_entry
    errors.add :hours, :invalid if hours && (hours < 0 || hours >= 1000)
    errors.add :project_id, :invalid if project.nil?
    errors.add :issue_id, :invalid if (issue_id && !issue) || (issue && project!=issue.project) || @invalid_issue_id
    errors.add :activity_id, :inclusion if activity_id_changed? && project && !project.activities.include?(activity)
  end

  def hours=(h)
    write_attribute :hours, (h.is_a?(String) ? (h.to_hours || h) : h)
  end

  def hours
    h = read_attribute(:hours)
    if h.is_a?(Float)
      h.round(2)
    else
      h
    end
  end

  # tyear, tmonth, tweek assigned where setting spent_on attributes
  # these attributes make time aggregations easier
  def spent_on=(date)
    super
    #self.tyear = spent_on ? spent_on.year : nil
    #self.tmonth = spent_on ? spent_on.month : nil
    #self.tweek = spent_on ? Date.civil(spent_on.year, spent_on.month, spent_on.day).cweek : nil
  end

  # Returns true if the time entry can be edited by usr, otherwise false
  def editable_by?(usr)
    visible?(usr)
  end

  # Returns the custom_field_values that can be edited by the given user
  def editable_custom_field_values(user=nil)
    visible_custom_field_values
  end

  # Returns the custom fields that can be edited by the given user
  def editable_custom_fields(user=nil)
    editable_custom_field_values(user).map(&:custom_field).uniq
  end

  private

  def add_user_as_watcher
    #Watcher.create(:watchable => self, :user => user)
  end

  def send_notification
    if Setting.notified_events.include?('k3n_timer_added')
      #Mailer.k3n_timer_added(self).deliver
    end
  end


end
