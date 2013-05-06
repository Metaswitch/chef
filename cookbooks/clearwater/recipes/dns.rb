# @file dns.rb
#
# Copyright (C) 2013  Metaswitch Networks Ltd
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# The author can be reached by email at clearwater@metaswitch.com or by post at
# Metaswitch Networks Ltd, 100 Church St, Enfield EN2 6BQ, UK

package "bind9" do
  action [:install]
  options "--force-yes"
end

template "/etc/bind/named.conf" do
  mode "0644"
  source "dns/named.conf"
  owner "root"
  group "bind"
end

template "/etc/bind/named.conf.internal-view" do
  mode "0644"
  source "dns/named.conf.internal-view.erb"
  variables node: node
  owner "root"
  group "bind"
end

template "/etc/bind/named.conf.external-view" do
  mode "0644"
  source "dns/named.conf.external-view"
  owner "root"
  group "bind"
end

template "/etc/bind/named.conf.internal-zones" do
  mode "0644"
  source "dns/named.conf.internal-zones"
  owner "root"
  group "bind"
end

template "/etc/bind/named.conf.external-zones" do
  mode "0644"
  source "dns/named.conf.external-zones"
  owner "root"
  group "bind"
end

service "bind9" do
  action :restart
end
