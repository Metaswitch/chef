# @file infrastructure.rb
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

require 'resolv'

# Tell apt about the Clearwater repository server.
template "/etc/apt/sources.list.d/clearwater.list" do
  mode "0644"
  source "apt.list.erb"
  variables({
    hostname: node[:clearwater][:repo_server],
    repos: ["binary/"]
  })
  notifies :run, "execute[apt-key-clearwater]", :immediately
end

# Fetch the key for the Clearwater repository server
execute "apt-key-clearwater" do
  user "root"
  command "curl -L http://repo.cw-ngv.com/repo_key | sudo apt-key add -"
  action :nothing
end

# Tell apt about the Cassandra repository server.
template "/etc/apt/sources.list.d/cassandra.list" do
  mode "0644"
  source "apt.list.erb"
  variables({
    hostname: "http://debian.datastax.com/community",
    repos: ["stable", "main"]
  })
  notifies :run, "execute[apt-key-cassandra]", :immediately
end

# Fetch the key for the Cassandra repository server
execute "apt-key-cassandra" do
  user "root"
  command "curl -L http://debian.datastax.com/debian/repo_key | sudo apt-key add -"
  action :nothing
end

# Make sure all packages are up to date (note this uses an external cookbook, in cookbooks/apt)
execute "apt-get update" do
  action :nothing
  subscribes :run, "execute[apt-key-clearwater]", :immediately
  subscribes :run, "execute[apt-key-cassandra]", :immediately
end

# Setup the clearwater config file
directory "/etc/clearwater" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

domain = if node[:clearwater][:use_subdomain]
           node.chef_environment + "." + node[:clearwater][:root_domain]
         else
           node[:clearwater][:root_domain]
         end

sas = Resolv::DNS.open { |dns| dns.getaddress(node[:clearwater][:sas_server]).to_s } rescue "0.0.0.0"
enum = Resolv::DNS.open { |dns| dns.getaddress(node[:clearwater][:enum_server]).to_s } rescue nil

if node.roles.include? "cw_aio"
  template "/etc/clearwater/config" do
    mode "0644"
    source "config.erb"
    variables domain: "example.com",
              node: node,
              sprout: "localhost",
              hs: "localhost:8888",
              homer: "localhost:7888",
              sas: sas,
              enum: enum
  end
  package "clearwater-auto-config-aws" do
    action [:install]
    options "--force-yes"
  end
else
  template "/etc/clearwater/config" do
    mode "0644"
    source "config.erb"
    variables domain: domain,
              node: node,
              sprout: "sprout." + domain,
              hs: "hs." + domain + ":8888",
              homer: "homer." + domain + ":7888",
              sas: sas,
              enum: enum
  end
end

package "clearwater-infrastructure" do
  action [:install]
  options "--force-yes"
end

package "clearwater-snmpd" do
  action [:install]
  options "--force-yes"
end

if node[:clearwater][:package_update_minutes]
  cron "package update" do
    minute ("*/" + node[:clearwater][:package_update_minutes].to_s)
    command "chef-client"
  end
end
