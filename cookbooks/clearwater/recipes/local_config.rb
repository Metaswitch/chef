# @file local_config.rb
#
# Copyright (C) Metaswitch Networks 2017
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

# Setup the clearwater local config file
directory "/etc/clearwater" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

# Set up the local config file

nodes = search(:node, "chef_environment:#{node.chef_environment}")

# Check if we have a GR deployment, and setup the correct configuration if we do.
if node[:clearwater][:num_gr_sites] && node[:clearwater][:num_gr_sites] > 1 && node[:clearwater][:site]
  number_of_sites = node[:clearwater][:num_gr_sites]

  # Set up an array of all the sites.
  sites = Array.new(number_of_sites)
  for i in 0...number_of_sites
      sites[i] = "site#{i+1}"
  end

  # Work out which site this node is in.
  local_site_index = node[:clearwater][:site]
  local_site = sites[local_site_index - 1]

  # Remove the local site to get the list of remote sites.
  sites.delete_at(local_site_index - 1)
  remote_sites = sites.join(",")

  # List all nodes in the remote sites as the remote_cassandra_nodes. This means
  # remote_cassandra_seeds will be set on all nodes (even though it's only ever
  # used on nodes with Cassandra).
  remote_cassandra_nodes = nodes.select do |n|
    if n[:clearwater] && n[:clearwater][:site] && n[:roles]
      n[:clearwater][:site] != local_site_index && n[:roles].sort == node[:roles].sort
    end
  end

  # Find all nodes in this site that have been marked as part of the etcd
  # cluster.
  etcd = nodes.select do |n|
    if n[:clearwater] && n[:clearwater][:site]
      n[:clearwater][:etcd_cluster] && n[:clearwater][:site] == local_site_index
    end
  end
else
  local_site = "site1"
  remote_sites = ""
  remote_cassandra_nodes = []

  # Find all nodes in the deployment that have been marked as part of the etcd
  # cluster.
  etcd = nodes.select do |n|
    if n[:clearwater]
      n[:clearwater][:etcd_cluster]
    end
  end
end

if node.role?("vellum")
  etcd_cluster_or_proxy = "etcd_cluster"
else
  etcd_cluster_or_proxy = "etcd_proxy"
end

# Create local_config
template "/etc/clearwater/local_config" do
    mode "0644"
    source "local_config.erb"
    variables node: node,
              etcd_cluster_or_proxy: etcd_cluster_or_proxy,
              etcd: etcd,
              local_site: local_site,
              remote_sites: remote_sites,
              remote_cassandra_nodes: remote_cassandra_nodes
end
