# @file shared_config.rb
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

require 'socket'

package "clearwater-management" do
  action [:install]
  options "--force-yes"
end

domain = if node[:clearwater][:use_subdomain]
           node.chef_environment + "." + node[:clearwater][:root_domain]
         else
           node[:clearwater][:root_domain]
         end

if node[:clearwater][:seagull]
  hss = "hss.seagull." + domain
  cdf = "cdf.seagull." + domain
else
  hss = nil
  cdf = "cdf." + domain
end

site_suffix = if node[:clearwater][:gr]
  if node[:clearwater][:index] and node[:clearwater][:index] % 2 == 1
    "-site1"
  else
    "-site2"
  end
else
  ""
end

sprout_aliases = ["sprout." + domain,
                  "sprout-site1." + domain,
                  "sprout-site2." + domain]

template "/etc/clearwater/shared_config" do
  mode "0644"
  source "shared_config.erb"
  variables domain: domain,
    node: node,
    sprout: "sprout#{site_suffix}.#{domain}",
    sprout_icscf: "icscf.sprout#{site_suffix}.#{domain}",
    alias_list: if node.roles.include? "sprout"
                  sprout_aliases.join(",")
                end,
    hs: "hs#{site_suffix}.#{domain}:8888",
    hs_prov: "hs#{site_suffix}.#{domain}:8889",
    homer: "homer#{site_suffix}.#{domain}:7888",
    ralf: if node[:clearwater][:ralf] and ((node[:clearwater][:ralf] == true) || (node[:clearwater][:ralf] > 0))
            "ralf#{site_suffix}.#{domain}:10888"
          end,
    cdf: cdf,
    hss: hss
  notifies :run, "ruby_block[wait_for_etcd]", :immediately
end

ruby_block "wait_for_etcd" do
  # Check that etcd is listening on port 4000 - we'll do more checks later
  block do
    loop do
      begin
        s = TCPSocket.new(node[:cloud][:local_ipv4], 4000)
        break
      rescue SystemCallError
        sleep 1
      end
    end
  end
  notifies :run, "execute[poll_etcd]", :immediately
  notifies :run, "execute[upload_shared_config]", :immediately

  # Only run the extra etcd scripts if we're on a Sprout node
  if node.run_list.any? { |s| s.to_s.include?('sprout') }
    notifies :run, "execute[upload_enum_json]", :immediately
    notifies :run, "execute[upload_bgcf_json]", :immediately
    notifies :run, "execute[upload_scscf_json]", :immediately
  end

  action :nothing
end

# Check that etcd can read/write keys, and well as listen on 4000
execute "poll_etcd" do
  user "root"
  command "/usr/share/clearwater/bin/poll_etcd.sh --quorum"
  retry_delay 1
  retries 60
end

execute "upload_shared_config" do
  user "root"
  command "/usr/share/clearwater/clearwater-config-manager/scripts/upload_shared_config"
  action :nothing
end

execute "upload_enum_json" do
  user "root"
  command "/usr/share/clearwater/clearwater-config-manager/scripts/upload_enum_json"
  action :nothing
end

execute "upload_bgcf_json" do
  user "root"
  command "/usr/share/clearwater/clearwater-config-manager/scripts/upload_bgcf_json"
  action :nothing
end

execute "upload_scscf_json" do
  user "root"
  command "/usr/share/clearwater/clearwater-config-manager/scripts/upload_scscf_json"
  action :nothing
end
