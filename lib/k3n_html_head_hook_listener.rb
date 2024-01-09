require_dependency 'user'

module K3nTimerUser
  module Patches
    module UserPatch
      def self.included(base) # :nodoc:
        base.class_eval do
          unloadable
          safe_attributes 'k3n_timer'
        end
      end
    end
  end
end

unless User.included_modules.include?(K3nTimerUser::Patches::UserPatch)
  User.send(:include, K3nTimerUser::Patches::UserPatch)
end

module K3nTimerMyHelper
  module Patches
    module MyHelperPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)
		base.class_eval do
          unloadable
        end
      end
	  module InstanceMethods
		def render_timelog_tab_block(block, settings)
			days = settings[:days].to_i
			days = 7 if days < 1 || days > 365
			office_total_hours = 0
			tab_path = 'redmine_hrm/'

			entries = TimeEntry.
			  where("#{TimeEntry.table_name}.user_id = ? AND #{TimeEntry.table_name}.spent_on BETWEEN ? AND ?", User.current.id, User.current.today - (days - 1), User.current.today).
			  joins(:activity, :project).
			  references(:issue => [:tracker, :status]).
			  includes(:issue => [:tracker, :status]).
			  order("#{TimeEntry.table_name}.spent_on DESC, #{Project.table_name}.name ASC, #{Tracker.table_name}.position ASC, #{Issue.table_name}.id ASC").
			  to_a
			entries_by_day = entries.group_by(&:spent_on)

			if Redmine::Plugin.installed?('redmine_hrm')
			  office_entries = HrmAttendance.
			    where("#{HrmAttendance.table_name}.user_id = ? AND hrm_attendance_type_id = 1 AND #{HrmAttendance.table_name}.attendance_date BETWEEN ? AND ?", User.current.id, User.current.today - (days - 1), User.current.today).
			    joins(:hrm_attendance_type).
			    order("#{HrmAttendance.table_name}.attendance_date DESC").
			    to_a
			  office_entries_by_day = office_entries.group_by(&:attendance_date)

			  office_entries.each do |item|
			    office_total_hours = office_total_hours + item.duration.fdiv(3600)
			  end
			else
			  tab_path = ''
			  office_entries = K3nTimer.
			    where("#{K3nTimer.table_name}.user_id = ? AND #{K3nTimer.table_name}.spent_on BETWEEN ? AND ?", User.current.id, User.current.today - (days - 1), User.current.today).
			    order("#{K3nTimer.table_name}.spent_on DESC").
			    to_a
			  office_entries_by_day = office_entries.group_by(&:spent_on)

			  office_entries.each do |item|
			    office_total_hours = office_total_hours + item.hours
			  end
			end 

			partial = 'my/blocks/tab/' + tab_path + 'timelog'

			render :partial => partial, :locals => {:block => block, :entries => entries, :entries_by_day => entries_by_day, :office_entries => office_entries, :office_entries_by_day => office_entries_by_day, :days => days}
		 end
		def render_office_timelog_tab_block(block, settings)
			days = settings[:days].to_i
			days = 7 if days < 1 || days > 365
			total_hours = 0
			tab_path = 'redmine_hrm/'

			if Redmine::Plugin.installed?('redmine_hrm')
			  entries = HrmAttendance.
			    where("#{HrmAttendance.table_name}.user_id = ? AND hrm_attendance_type_id = 1 AND #{HrmAttendance.table_name}.attendance_date BETWEEN ? AND ?", User.current.id, User.current.today - (days - 1), User.current.today).
			    joins(:hrm_attendance_type).
			    order("#{HrmAttendance.table_name}.attendance_date DESC").
			    to_a
			  entries_by_day = entries.group_by(&:attendance_date)

			  entries.each do |item|
			    total_hours = total_hours + item.duration.fdiv(3600)
			  end
			else
			  tab_path = ''
			  entries = K3nTimer.
			    where("#{K3nTimer.table_name}.user_id = ? AND #{K3nTimer.table_name}.spent_on BETWEEN ? AND ?", User.current.id, User.current.today - (days - 1), User.current.today).
			    order("#{K3nTimer.table_name}.spent_on DESC").
			    to_a
			  entries_by_day = entries.group_by(&:spent_on)

			  entries.each do |item|
			    total_hours = total_hours + item.hours
			  end
			end

			partial = 'my/blocks/tab/' + tab_path + 'office_timelog'

			render :partial => partial, :locals => {:block => block, :entries => entries, :entries_by_day => entries_by_day, :days => days, :total_hours => total_hours}
		 end
	  end
    end
  end
end

unless MyHelper.included_modules.include?(K3nTimerMyHelper::Patches::MyHelperPatch)
  MyHelper.send(:include, K3nTimerMyHelper::Patches::MyHelperPatch)
end


module K3nTimerHookViewUsers
  module Hooks
    class ViewsUserFormHook < Redmine::Hook::ViewListener
      render_on :view_users_form, :partial => "users/k3n_timer"
    end
  end
end


class K3nHtmlHeadHookListener < Redmine::Hook::ViewListener
  render_on :view_layouts_base_html_head, :partial => "k3n_timer/log_time"
end
