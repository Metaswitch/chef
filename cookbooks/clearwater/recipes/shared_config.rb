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

if node[:clearwater][:num_gr_sites]
  number_of_sites = node[:clearwater][:num_gr_sites]
else
  number_of_sites = 1
end

site_suffix = if number_of_sites > 1 && node[:clearwater][:site]
  "-site#{node[:clearwater][:site]}"
else
  ""
end

if node[:clearwater][:split_storage]
  sprout_registration_store = "\"site1=vellum-site1.#{domain}"
  for i in 2..number_of_sites
    sprout_registration_store = "#{sprout_registration_store},site#{i}=vellum-site#{i}.#{domain}"
  end
else
  sprout_registration_store = "\"site1=sprout-site1.#{domain}"
  for i in 2..number_of_sites
    sprout_registration_store = "#{sprout_registration_store},site#{i}=sprout-site#{i}.#{domain}"
  end
end
sprout_registration_store = "#{sprout_registration_store}\""

if node[:clearwater][:split_storage]
  sprout_impi_store = "vellum#{site_suffix}.#{domain}"
  chronos_hostname = "vellum#{site_suffix}.#{domain}"
else
  sprout_impi_store = "localhost"
  chronos_hostname = "localhost"
end

if node[:clearwater][:split_storage]
  cassandra_hostname = "vellum#{site_suffix}.#{domain}"
else
  cassandra_hostname = "localhost"
end

ralf_session_store = "\"site1=ralf-site1.#{domain}"
for i in 2..number_of_sites
  ralf_session_store = "#{ralf_session_store},site#{i}=ralf-site#{i}.#{domain}"
end
ralf_session_store = "#{ralf_session_store}\""

sprout_aliases = ["sprout." + domain]

for i in 1..number_of_sites
  sprout_aliases.push("sprout-site#{i}." + domain)
end

if node[:clearwater][:split_storage]
  # We have dime nodes running the ralf process
  ralf = "ralf#{site_suffix}.#{domain}:10888"
else
  if node[:clearwater][:ralf] and ((node[:clearwater][:ralf] == true) || (node[:clearwater][:ralf] > 0))
    ralf = "ralf#{site_suffix}.#{domain}:10888"
  end
end

template "/etc/clearwater/shared_config" do
  mode "0644"
  source "shared_config.erb"
  variables domain: domain,
    node: node,
    sprout: "sprout#{site_suffix}.#{domain}",
    alias_list: if node.roles.include? "sprout"
                  sprout_aliases.join(",")
                end,
    hs: "hs#{site_suffix}.#{domain}:8888",
    hs_prov: "hs#{site_suffix}.#{domain}:8889",
    homer: "homer#{site_suffix}.#{domain}:7888",
    ralf: ralf,
    cdf: cdf,
    hss: hss,
    cassandra_hostname: cassandra_hostname,
    chronos_hostname: chronos_hostname,
    sprout_impi_store: sprout_impi_store,
    sprout_registration_store: sprout_registration_store,
    ralf_session_store: ralf_session_store,
    memento_auth_store: "sprout#{site_suffix}.#{domain}",
    scscf_uri: "sip:scscf.sprout#{site_suffix}.#{domain}",
    upstream_port: 0
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
