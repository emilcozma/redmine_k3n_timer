# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

#custom routes for this plugin
RedmineApp::Application.routes.draw do
  match '/office_time_entries' => 'k3n_timer#index', :via => [:get], :as => 'k3n_timer_index'
  match '/office_time_entries/new' => 'k3n_timer#new', :via => [:get, :post], :as => 'k3n_timer_new'
  match '/office_time_entries/create' => 'k3n_timer#create', :via => [:get, :post], :as => 'k3n_timer_create'
  match '/office_time_entries/show/:id' => 'k3n_timer#show', :via => [:get, :post], :as => 'k3n_timer_show'
  match '/office_time_entries/edit/:id' => 'k3n_timer#edit', :via => [:get, :post], :as => 'k3n_timer_edit'
  match '/office_time_entries/update/:id' => 'k3n_timer#update', :via => [:get, :post, :put, :patch], :as => 'k3n_timer_update'
  match '/office_time_entries/delete/:id' => 'k3n_timer#delete', :via => [:get, :post, :delete], :as => 'k3n_timer_delete'
  match '/office_time_entries/report' => 'k3n_timer#report', :via => [:get, :post], :as => 'k3n_timer_report'
end
