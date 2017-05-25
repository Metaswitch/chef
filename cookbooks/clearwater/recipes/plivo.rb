# @file plivo.rb
#
# Copyright (C) Metaswitch Networks
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

package "libevent-dev" do
  action [:install]
end

execute "#{Chef::Config[:file_cache_path]}/install.sh" do
  action :nothing
end

remote_file "#{Chef::Config[:file_cache_path]}/install.sh" do
  source "https://github.com/plivo/plivoframework/raw/master/freeswitch/install.sh"
  mode "0755"
  not_if { ::Dir.exists? "/usr/local/freeswitch" }
  notifies :run, "execute[#{Chef::Config[:file_cache_path]}/install.sh]", :immediately
end

# This is a massive hack.  It looks as thought plivo now only installs below /usr/plivo, but
# we want it to be below /usr/local/plivo so first install it under /usr/plivo and then
# reinstall it below /usr/local/plivo.
execute "#{Chef::Config[:file_cache_path]}/plivo_install.sh_usr_plivo" do
  command "#{Chef::Config[:file_cache_path]}/plivo_install.sh /usr/plivo"
  action :nothing
  notifies :run, "execute[#{Chef::Config[:file_cache_path]}/plivo_install.sh]", :immediately
end

execute "#{Chef::Config[:file_cache_path]}/plivo_install.sh" do
  command "#{Chef::Config[:file_cache_path]}/plivo_install.sh /usr/local/plivo"
  action :nothing
end

remote_file "#{Chef::Config[:file_cache_path]}/plivo_install.sh" do
  source "https://github.com/plivo/plivoframework/raw/master/scripts/plivo_install.sh"
  mode "0755"
  not_if { ::Dir.exists? "/usr/local/plivo" }
  notifies :run, "execute[#{Chef::Config[:file_cache_path]}/plivo_install.sh_usr_plivo]", :immediately
end

template "/usr/local/freeswitch/conf/vars.xml" do
  mode "0644"
  source "plivo/vars.xml.erb"
  variables node: node
  owner "root"
  group "root"
end

template "/usr/local/freeswitch/conf/sip_profiles/external.xml" do
  mode "0644"
  source "plivo/external.xml.erb"
  variables node: node
  owner "root"
  group "root"
end

template "/usr/local/freeswitch/conf/sip_profiles/internal.xml" do
  mode "0644"
  source "plivo/internal.xml.erb"
  variables node: node
  owner "root"
  group "root"
end

cookbook_file "/usr/local/freeswitch/conf/autoload_configs/switch.conf.xml" do
  mode "0644"
  source "plivo/switch.conf.xml"
  owner "root"
  group "root"
end

cookbook_file "/etc/init.d/freeswitch" do
  mode "0755"
  source "plivo/freeswitch.init.d"
  owner "root"
  group "root"
end

cookbook_file "/usr/local/plivo/etc/plivo/default.conf" do
  mode "0644"
  source "plivo/default.conf"
  owner "root"
  group "root"
end

service "freeswitch" do
  action :start
end

service "plivo" do
  action :start
end
