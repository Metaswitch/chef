# @file security.rb
#
# Project Clearwater - IMS in the Cloud
# Copyright (C) 2015  Metaswitch Networks Ltd
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

directory "/etc/apt/certs/clearwater" do
  owner "root"
  group "root"
  mode "0755"
  action :create
  recursive true
  notifies :run, "ruby_block[get-secret-key]", :immediately
  notifies :create, "template[/etc/apt/apt.conf.d/45_clearwater_repo]", :immediately
  only_if { node[:clearwater][:repo_servers].any? { |rs| URI(rs).scheme == "https" } }
end

ruby_block "get-secret-key" do
  block do
    keys = Chef::EncryptedDataBagItem.load("repo_keys", "generic")
    File.open("/etc/apt/certs/clearwater/repository-ca.crt",'w') { |f|
      f.write(keys["repository-ca.crt"])
    }
    File.open("/etc/apt/certs/clearwater/repository-server.crt",'w') { |f|
      f.write(keys["repository-server.crt"])
    }
    File.open("/etc/apt/certs/clearwater/repository-server.key",'w') { |f|
      f.write(keys["repository-server.key"])
    }
  end
  action :nothing
end

# Tell apt about the Clearwater repository server's security keys'.
template "/etc/apt/apt.conf.d/45_clearwater_repo" do
  mode "0644"
  source "apt.keys.erb"
  variables repo_hosts: node[:clearwater][:repo_servers].select { |rs| URI(rs).scheme == "https" }.map { |rs| URI(rs).host }
  action :nothing
end

# Tell apt about the Clearwater repository server.
template "/etc/apt/sources.list.d/clearwater.list" do
  mode "0644"
  source "apt.list.erb"
  variables hostnames: node[:clearwater][:repo_servers],
            repos: ["binary/"]
  notifies :run, "execute[apt-key-clearwater]", :immediately
end

# Fetch the key for the Clearwater repository server
execute "apt-key-clearwater" do
  user "root"
  command "curl -L http://repo.cw-ngv.com/repo_key | sudo apt-key add -"
  action :nothing
end

# Make sure all packages are up to date (note this uses an external cookbook, in cookbooks/apt)
execute "apt-get update" do
  action :nothing
  subscribes :run, "execute[apt-key-clearwater]", :immediately
end

