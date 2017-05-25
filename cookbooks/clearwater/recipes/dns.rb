# @file dns.rb
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

# Copy the config on.  Some files are static, and so use cookbook_file (and
# come from the files/ directory).  Other files are dynamic, and so use
# template (and come from the templates/ directory).
cookbook_file "/etc/bind/named.conf" do
  mode "0644"
  source "dns/named.conf"
  owner "root"
  group "bind"
end

template "/etc/bind/named.conf.internal-view" do
  mode "0644"
  source "dns/named.conf.internal-view.erb"
  variables node: node
  owner "root"
  group "bind"
end

cookbook_file "/etc/bind/named.conf.external-view" do
  mode "0644"
  source "dns/named.conf.external-view"
  owner "root"
  group "bind"
end

cookbook_file "/etc/bind/named.conf.internal-zones" do
  mode "0644"
  source "dns/named.conf.internal-zones"
  owner "root"
  group "bind"
end

cookbook_file "/etc/bind/named.conf.external-zones" do
  mode "0644"
  source "dns/named.conf.external-zones"
  owner "root"
  group "bind"
end

directory "/var/cache/bind/zones" do
  owner "bind"
  group "bind"
  action :create
end

service "bind9" do
  action :restart
end
