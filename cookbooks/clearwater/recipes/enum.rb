# @file enum.rb
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
  source "enum/named.conf"
end

template "/etc/bind/named.conf.e164.arpa" do
  mode "0644"
  source "enum/named.conf.e164.arpa"
  owner "root"
  group "bind"
end

domain = if node.chef_environment != "_default"
           node.chef_environment + "." + node[:clearwater][:root_domain]
         else
           node[:clearwater][:root_domain]
         end

template "/etc/bind/e164.arpa.db" do
  mode "0644"
  source "enum/e164.arpa.db.erb"
  variables domain: domain,
            node: node
  owner "root"
  group "bind"
end

service "bind9" do
  action :restart
end
