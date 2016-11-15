# @file chronos.rb
#
# Project Clearwater - IMS in the Cloud
# Copyright (C) 2016  Metaswitch Networks Ltd
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

directory "/etc/chronos" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

# Check if we have a GR deployment, and setup the correct configuration if we do.
if node[:clearwater][:num_gr_sites] && node[:clearwater][:num_gr_sites] > 1 && node[:clearwater][:index]
  number_of_sites = node[:clearwater][:num_gr_sites]

  # Set up the local site
  local_site_index = node[:clearwater][:index] % number_of_sites
  if local_site_index == 0
    local_site_index = number_of_sites
  end

  local_site="site#{local_site_index}"

  # Set up the remote sites
  domain = node.chef_environment + "." + node[:clearwater][:root_domain]
  for i in 1..number_of_sites
    remote_sites = "#{remote_sites}remote_site = site#{i}=chronos-site#{i}.#{domain}\n"
  end
else
  local_site = "single_site"
  remote_sites = ""
end

# Create the Chronos GR config
template "/etc/chronos/chronos_gr.conf" do
    mode "0644"
    source "chronos_gr.conf.erb"
    variables local_site: local_site,
              remote_sites: remote_sites
end
