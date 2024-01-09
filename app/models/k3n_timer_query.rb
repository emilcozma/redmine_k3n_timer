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

class K3nTimerQuery < Query

  self.queried_class = K3nTimer
  self.view_permission = :view_time_entries

  self.available_columns = [
    QueryColumn.new(:spent_on, :sortable => ["#{K3nTimer.table_name}.spent_on", "#{K3nTimer.table_name}.created_on"], :default_order => 'desc', :groupable => true),
    QueryColumn.new(:tweek, :sortable => ["#{K3nTimer.table_name}.spent_on", "#{K3nTimer.table_name}.created_on"], :caption => :label_week),
	QueryColumn.new(:user, :sortable => lambda {User.fields_for_order_statement}, :groupable => true),
    QueryColumn.new(:comments),
    QueryColumn.new(:hours, :sortable => "#{K3nTimer.table_name}.hours", :totalable => true),
  ]

  def initialize(attributes=nil, *args)
    super attributes
    self.filters ||= { 'spent_on' => {:operator => "*", :values => []} }
  end

  def initialize_available_filters
    add_available_filter "spent_on", :type => :date_past

	add_available_filter("user_id",
      :type => :list_optional, :values => lambda { author_values }
    )

    add_available_filter "comments", :type => :text
    add_available_filter "hours", :type => :float
  end

  def available_columns
    return @available_columns if @available_columns
    @available_columns = self.class.available_columns.dup
    @available_columns
  end

  def default_columns_names
    @default_columns_names ||= begin
      default_columns = [:spent_on, :comments, :hours]

      default_columns
    end
  end

  def default_totalable_names
    [:hours]
  end

  def default_sort_criteria
    [['spent_on', 'desc']]
  end

  # If a filter against a single issue is set, returns its id, otherwise nil.
  def filtered_issue_id
    if value_for('issue_id').to_s =~ /\A(\d+)\z/
      $1
    end
  end

  def base_scope
    K3nTimer.visible.
      where(statement)
  end

  def results_scope(options={})
    order_option = [group_by_sort_order, (options[:order] || sort_clause)].flatten.reject(&:blank?)

    base_scope.
      order(order_option).
      joins(joins_for_order_statement(order_option.join(',')))
  end

  # Returns sum of all the spent hours
  def total_for_hours(scope)
    map_total(scope.sum(:hours)) {|t| t.to_f.round(2)}
  end

  def sql_for_issue_id_field(field, operator, value)
    case operator
    when "="
      "#{K3nTimer.table_name}.issue_id = #{value.first.to_i}"
    when "~"
      issue = Issue.where(:id => value.first.to_i).first
      if issue && (issue_ids = issue.self_and_descendants.pluck(:id)).any?
        "#{K3nTimer.table_name}.issue_id IN (#{issue_ids.join(',')})"
      else
        "1=0"
      end
    when "!*"
      "#{K3nTimer.table_name}.issue_id IS NULL"
    when "*"
      "#{K3nTimer.table_name}.issue_id IS NOT NULL"
    end
  end

  def sql_for_issue_fixed_version_id_field(field, operator, value)
    issue_ids = Issue.where(:fixed_version_id => value.map(&:to_i)).pluck(:id)
    case operator
    when "="
      if issue_ids.any?
        "#{K3nTimer.table_name}.issue_id IN (#{issue_ids.join(',')})"
      else
        "1=0"
      end
    when "!"
      if issue_ids.any?
        "#{K3nTimer.table_name}.issue_id NOT IN (#{issue_ids.join(',')})"
      else
        "1=1"
      end
    end
  end

  def sql_for_activity_id_field(field, operator, value)
    condition_on_id = sql_for_field(field, operator, value, Enumeration.table_name, 'id')
    condition_on_parent_id = sql_for_field(field, operator, value, Enumeration.table_name, 'parent_id')
    ids = value.map(&:to_i).join(',')
    table_name = Enumeration.table_name
    if operator == '='
      "(#{table_name}.id IN (#{ids}) OR #{table_name}.parent_id IN (#{ids}))"
    else
      "(#{table_name}.id NOT IN (#{ids}) AND (#{table_name}.parent_id IS NULL OR #{table_name}.parent_id NOT IN (#{ids})))"
    end
  end

  def sql_for_issue_tracker_id_field(field, operator, value)
    sql_for_field("tracker_id", operator, value, Issue.table_name, "tracker_id")
  end

  def sql_for_issue_status_id_field(field, operator, value)
    sql_for_field("status_id", operator, value, Issue.table_name, "status_id")
  end

  # Accepts :from/:to params as shortcut filters
  def build_from_params(params)
    super
    if params[:from].present? && params[:to].present?
      add_filter('spent_on', '><', [params[:from], params[:to]])
    elsif params[:from].present?
      add_filter('spent_on', '>=', [params[:from]])
    elsif params[:to].present?
      add_filter('spent_on', '<=', [params[:to]])
    end
    self
  end

  def joins_for_order_statement(order_options)
    joins = [super]

    if order_options
      if order_options.include?('issue_statuses')
        joins << "LEFT OUTER JOIN #{IssueStatus.table_name} ON #{IssueStatus.table_name}.id = #{Issue.table_name}.status_id"
      end
      if order_options.include?('trackers')
        joins << "LEFT OUTER JOIN #{Tracker.table_name} ON #{Tracker.table_name}.id = #{Issue.table_name}.tracker_id"
      end
    end

    joins.compact!
    joins.any? ? joins.join(' ') : nil
  end
end
