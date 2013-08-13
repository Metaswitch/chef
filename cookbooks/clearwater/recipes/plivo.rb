# @file plivo.rb
#
# Project Clearwater - IMS in the Cloud
# Copyright (C) 2013  Metaswitch Networks Ltd
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version, along with the "Special Exception" for use of
# the program along with SSL, set forth below. This program is distributed
# in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details. You should have received a copy of the GNU General Public
# License along with this program.  If not, see
# <http://www.gnu.org/licenses/>.
#
# The author can be reached by email at clearwater@metaswitch.com or by
# post at Metaswitch Networks Ltd, 100 Church St, Enfield EN2 6BQ, UK
#
# Special Exception
# Metaswitch Networks Ltd  grants you permission to copy, modify,
# propagate, and distribute a work formed by combining OpenSSL with The
# Software, or a work derivative of such a combination, even if such
# copying, modification, propagation, or distribution would otherwise
# violate the terms of the GPL. You must comply with the GPL in all
# respects for all of the code used other than OpenSSL.
# "OpenSSL" means OpenSSL toolkit software distributed by the OpenSSL
# Project and licensed under the OpenSSL Licenses, or a work based on such
# software and licensed under the OpenSSL Licenses.
# "OpenSSL Licenses" means the OpenSSL License and Original SSLeay License
# under which the OpenSSL Project distributes the OpenSSL toolkit software,
# as those licenses appear in the file LICENSE-OPENSSL.

package "libevent-dev" do
  action [:install]
  options "--force-yes"
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
# reinstall it below /usr/plivo.
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
