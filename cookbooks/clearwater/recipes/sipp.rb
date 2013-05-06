# @file sipp.rb
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

bonos = search(:node,
               "role:bono AND chef_environment:#{node.chef_environment}")
bonos.sort! { |a,b| a[:clearwater][:index] <=> b[:clearwater][:index] }
bonos.map! { |n| n[:cloud][:local_ipv4] }

template "/etc/clearwater/cluster_settings" do
  source "sipp/cluster_settings.erb"
  variables server_list: bonos
end

package "clearwater-sip-stress" do
  action [:install]
  options "--force-yes"
end
