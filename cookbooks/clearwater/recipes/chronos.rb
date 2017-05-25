# @file chronos.rb
#
# Copyright (C) Metaswitch Networks
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

directory "/etc/chronos" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

# Check if we have a GR deployment, and setup the correct configuration if we do.
if node[:clearwater][:num_gr_sites] && node[:clearwater][:num_gr_sites] > 1 && node[:clearwater][:site]
  number_of_sites = node[:clearwater][:num_gr_sites]

  # Set up the local site
  local_site = "site#{node[:clearwater][:site]}"

  # Set up the remote sites
  domain = node.chef_environment + "." + node[:clearwater][:root_domain]
  for i in 1..number_of_sites
    remote_sites = "#{remote_sites}remote_site = site#{i}=vellum-site#{i}.#{domain}\n"
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
