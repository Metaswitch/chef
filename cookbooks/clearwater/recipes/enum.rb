# @file enum.rb
#
# Copyright (C) Metaswitch Networks
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

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

domain = if node[:clearwater][:use_subdomain]
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
