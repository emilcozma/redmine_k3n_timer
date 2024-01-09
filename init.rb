require 'redmine'
require_dependency 'k3n_html_head_hook_listener'

Redmine::Plugin.register :k3n_timer do
  name 'keeen timer'
  author 'Emil COZMA'
  description "This is a really simple check in/out to office plugin."
  version '1.0.0'
  author_url 'https://www.cozma.es'
      
  #menu :top_menu, :k3n_timer, {:controller => 'k3n_timer', :action => 'index'}, :caption => :label_k3n_timer, :if => Proc.new {User.current.k3n_timer?}, :after => :projects, :require => :loggedin
  #menu :application_menu, :k3n_timer, {:controller => 'k3n_timer', :action => 'index'}, :caption => :label_k3n_timer, :if => Proc.new {User.current.k3n_timer?}, :after => :time_entries, :require => :loggedin
end
