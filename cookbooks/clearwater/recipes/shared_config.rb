# @file shared_config.rb
#
# Copyright (C) Metaswitch Networks
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

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

sprout_registration_store = "\"site1=vellum-site1.#{domain}"
ralf_session_store = "\"site1=vellum-site1.#{domain}"
for i in 2..number_of_sites
  sprout_registration_store = "#{sprout_registration_store},site#{i}=vellum-site#{i}.#{domain}"
  ralf_session_store = "#{ralf_session_store},site#{i}=vellum-site#{i}.#{domain}"
end

sprout_impi_store = "vellum#{site_suffix}.#{domain}"
chronos_hostname = "vellum#{site_suffix}.#{domain}"
cassandra_hostname = "vellum#{site_suffix}.#{domain}"

# We have dime nodes running the ralf process
ralf = "ralf#{site_suffix}.#{domain}:10888"
sprout_registration_store = "#{sprout_registration_store}\""
ralf_session_store = "#{ralf_session_store}\""

sprout_aliases = ["sprout." + domain]
for i in 1..number_of_sites
  sprout_aliases.push("sprout-site#{i}." + domain)
end

template "/etc/clearwater/shared_config" do
  mode "0644"
  source "shared_config.erb"
  variables domain: domain,
    node: node,
    sprout: "sprout#{site_suffix}.#{domain}",
    sprout_mgmt: "sprout#{site_suffix}.#{domain}:9886",
    alias_list: if node.roles.include? "sprout"
                  sprout_aliases.join(",")
                end,
    hs: "hs#{site_suffix}.#{domain}:8888",
    hs_mgmt: "hs#{site_suffix}.#{domain}:8886",
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
    memento_auth_store: "vellum#{site_suffix}.#{domain}",
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
