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
require 'uri'

directory "/etc/apt/certs/clearwater" do
  owner "root"
  group "root"
  mode "0755"
  action :create
  recursive true
  notifies :run, "ruby_block[get-secret-key]", :immediately
  notifies :create, "template[/etc/apt/apt.conf.d/45_clearwater_repo]", :immediately
  only_if { URI(node[:clearwater][:repo_server]).scheme == "https" }
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
  variables repo_host: URI(node[:clearwater][:repo_server]).host
  action :nothing
end

# Tell apt about the Clearwater repository server.
template "/etc/apt/sources.list.d/clearwater.list" do
  mode "0644"
  source "apt.list.erb"
  variables hostname: node[:clearwater][:repo_server],
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

unless Chef::Config[:solo]

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

  if node[:clearwater][:seagull]
    hss = "hss.seagull." + domain
    cdf = "cdf.seagull." + domain
  else
    hss = nil
    cdf = "cdf." + domain
  end

  ralf = if node[:clearwater][:ralf] and ((node[:clearwater][:ralf] == true) || (node[:clearwater][:ralf] > 0))
           "ralf." + domain + ":10888"
         else
           ""
         end

  enum = Resolv::DNS.open { |dns| dns.getaddress(node[:clearwater][:enum_server]).to_s } rescue nil

  # Find all nodes in the deployment that have been marked as clustered. 
  nodes = search(:node, "chef_environment:#{node.chef_environment}")
  etcd = nodes.find_all { |s| s[:clearwater] && s[:clearwater][:etcd_cluster] }

  # If we want to do GR testing, split the deployment so that every other node is configured to be
  # in a different site. (This lets us test GR config is working, without having to set up a VPN or
  # tunneling to allow traffic between regions or deployments.)
  if node[:clearwater][:gr]
    if node[:clearwater][:index] % 2 == 1
      local_site = "odd_numbers"
      remote_site = "even_numbers"
    else
      local_site = "even_numbers"
      remote_site = "odd_numbers"
    end
  else
    local_site = "single_site"
    remote_site = ""
  end


  # Set up template values for /etc/clearwater/config - any new values should
  # be added for all-in-one and distributed installs
  # Ralf isn't currently part of the all-in-one image
  # There will also only ever be the local node in the etcd cluster, so we
  # can set this now
  if node.roles.include? "cw_aio"
    template "/etc/clearwater/config" do
      mode "0644"
      source "config.erb"
      variables domain: "example.com",
                node: node,
                sprout: node[:cloud][:public_hostname],
                hs: node[:cloud][:local_ipv4] + ":8888",
                hs_prov: node[:cloud][:local_ipv4] + ":8889",
                homer: node[:cloud][:local_ipv4] + ":7888",
                chronos: node[:cloud][:local_ipv4] + ":7253",
                ralf: "",
                cdf: "",
                enum: enum,
                hss: hss,
                etcd: node[:cloud][:local_ipv4],
                local_site: local_site,
                remote_site: remote_site
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
                sprout_icscf: "sprout-icscf." + domain,
                alias_list: if node.roles.include? "sprout"
                              "sprout-icscf." + domain
                             end,
                hs: "hs." + domain + ":8888",
                hs_prov: "hs." + domain + ":8889",
                homer: "homer." + domain + ":7888",
                chronos: node[:cloud][:local_ipv4] + ":7253",
                ralf: ralf,
                cdf: cdf,
                enum: enum,
                hss: hss,
                etcd: etcd,
                local_site: local_site,
                remote_site: remote_site
    end
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
  package "clearwater-auto-upgrade" do
    action [:install]
    options "--force-yes"
  end

  cron "package update" do
    minute ("*/" + node[:clearwater][:package_update_minutes].to_s)
    command "service clearwater-auto-upgrade restart"
  end
end
