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

class K3nTimerController < ApplicationController
  menu_item :k3n_timer

  before_action :find_office_time_entry, :only => [:show, :edit, :update]
  before_action :check_editability, :only => [:edit, :update]
  before_action :find_time_entries, :only => [:destroy]
  #before_action :authorize, :only => [:show, :edit, :update, :destroy]

  before_action :authorize_user_k3n_timer, :only => [:index, :current_day, :new, :create, :delete, :edit, :update, :report]

  accept_rss_auth :index
  accept_api_auth :index, :current_day, :show, :create, :update, :destroy

  rescue_from Query::StatementInvalid, :with => :query_statement_invalid

  helper :issues
  include K3nTimerHelper
  helper :custom_fields
  include CustomFieldsHelper
  helper :queries
  include QueriesHelper

  def index
    retrieve_office_time_entry_query
    scope = office_time_entry_scope

    respond_to do |format|
      format.html {
        @entry_count = scope.count
        @entry_pages = Paginator.new @entry_count, per_page_option, params['page']
        @entries = scope.offset(@entry_pages.offset).limit(@entry_pages.per_page).to_a

        render :layout => !request.xhr?
      }
      format.api  {
        @entry_count = scope.count
        @offset, @limit = api_offset_and_limit
        @entries = scope.offset(@offset).limit(@limit).to_a
      }
      format.atom {
        entries = scope.limit(Setting.feeds_limit.to_i).reorder("#{K3nTimer.table_name}.created_on DESC").to_a
        render_feed(entries, :title => l(:label_k3n_time))
      }
      format.csv {
        # Export all entries
        @entries = scope.to_a
        send_data(query_to_csv(@entries, @query, params), :type => 'text/csv; header=present', :filename => 'office_timelog.csv')
      }
    end
  end

  def report
    retrieve_office_time_entry_query
    scope = office_time_entry_scope

    @report = Redmine::Helpers::TimeReport.new(nil, nil, params[:criteria], params[:columns], scope)

    respond_to do |format|
      format.html { render :layout => !request.xhr? }
      format.csv  { send_data(report_to_csv(@report), :type => 'text/csv; header=present', :filename => 'timelog.csv') }
    end
  end

  def show
    respond_to do |format|
      # TODO: Implement html response
      format.html { head 406 }
      format.api
    end
  end

  def new
    @office_time_entry ||= K3nTimer.new(:user => User.current, :spent_on => User.current.today)
    @office_time_entry.safe_attributes = params[:k3n_timer]
  end

  def create
    @office_time_entry ||= K3nTimer.new(:user => User.current, :spent_on => User.current.today)
    @office_time_entry.safe_attributes = params[:k3n_timer]
    #if !User.current.allowed_to?(:edit_k3n_timer)
    #  render_403
    #  return
    #end

    if @office_time_entry.save
      respond_to do |format|
        format.html {
          flash[:notice] = l(:notice_successful_create)
          if params[:continue]
            options = {
              :id => @office_time_entry
            }
            redirect_to k3n_timer_edit_path(options)
          else
            redirect_back_or_default :k3n_timer_index
          end
        }
        format.api  { 
			#add HRM time if redmine_hrm plugin is active
			if Redmine::Plugin.installed?('redmine_hrm')
			  @HrmAttendance = HrmAttendance.new(:author => User.current, :user => User.current, :attendance_date => params[:k3n_timer][:spent_on], :hrm_attendance_type_id => 1, :start_time => params[:k3n_timer][:start_time], :end_time => params[:k3n_timer][:end_time], :description => params[:k3n_timer][:description])
			  @HrmAttendance.save
			end
			flash[:notice] = l(:notice_successful_create)
			render :json => {:office_time_entry => @office_time_entry, :status => :created, :redirect_url => user_hrm_attendances_path(User.current)}
		}
      end
    else
      respond_to do |format|
        format.html { render :action => 'new' }
        format.api  { render_validation_errors(@office_time_entry) }
      end
    end
  end

  def edit
    @office_time_entry.safe_attributes = params[:k3n_timer]
  end

  def update
    @office_time_entry.safe_attributes = params[:k3n_timer]

    if @office_time_entry.save
      respond_to do |format|
        format.html {
          flash[:notice] = l(:notice_successful_update)
          redirect_back_or_default :k3n_timer_index
        }
        format.api  { render_api_ok }
      end
    else
      respond_to do |format|
        format.html { render :action => 'edit' }
        format.api  { render_validation_errors(@office_time_entry) }
      end
    end
  end

  def delete
    @office_time_entry = K3nTimer.find(params[:id])
    @office_time_entry.destroy
	flash[:notice] = l(:notice_successful_delete)
    redirect_to :action => 'index'
  end

  def destroy
    destroyed = K3nTimer.transaction do
      @time_entries.each do |t|
        unless t.destroy && t.destroyed?
          raise ActiveRecord::Rollback
        end
      end
    end

    respond_to do |format|
      format.html {
        if destroyed
          flash[:notice] = l(:notice_successful_delete)
        else
          flash[:error] = l(:notice_unable_delete_office_time_entry)
        end
        redirect_back_or_default project_time_entries_path(@projects.first), :referer => true
      }
      format.api  {
        if destroyed
          render_api_ok
        else
          render_validation_errors(@time_entries)
        end
      }
    end
  end

private
  def authorize_user_k3n_timer
	if User.current.k3n_timer?
	  true
	else
	  deny_access
	end
  end

  def find_office_time_entry
    @office_time_entry = K3nTimer.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def check_editability
    unless @office_time_entry.editable_by?(User.current)
      render_403
      return false
    end
  end

  def find_time_entries
    @office_time_entries = K3nTimer.where(:id => params[:id] || params[:ids]).
      preload(:user).to_a

    raise ActiveRecord::RecordNotFound if @office_time_entries.empty?
    raise Unauthorized unless @office_time_entries.all? {|t| t.editable_by?(User.current)}
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Returns the K3nTimer scope for index and report actions
  def office_time_entry_scope(options={})
    @query.results_scope(options)
  end

  def retrieve_office_time_entry_query
    retrieve_query(K3nTimerQuery, false)
  end
end
