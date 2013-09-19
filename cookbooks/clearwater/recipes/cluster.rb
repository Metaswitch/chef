# @file cluster.rb
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

# We need the Cassandra-CQL gem later, install it as a pre-requisite.
build_essential_action = apt_package "build-essential" do
  action :nothing
end
build_essential_action.run_action(:install)

chef_gem "cassandra-cql" do
  action :install
  source "https://rubygems.org"
end

# Work out whether we're geographically-redundant.  In this case, we'll need to
# configure things to use public IP addresses rather than local.
gr_environments = node[:clearwater][:gr_environments] || [node.chef_environment]
is_gr = (gr_environments.length > 1)

# Clustering for Sprout nodes.
if node.run_list.include? "role[sprout]"
  sprouts = search(:node,
                   "role:sprout AND chef_environment:#{node.chef_environment}")
  sprouts.delete_if { |n| n.name == node.name }
  sprouts.map! { |s| s.cloud.public_hostname }

  other_gr_environments = gr_environments.reject { |e| e == node.chef_environment }
  remote_memstores = if not other_gr_environments.empty?
                       search(:node, "role:sprout AND chef_environment:#{other_gr_environments[0]}")
                     else
                       []
                     end
  template "/etc/clearwater/cluster_settings" do
    source "cluster/cluster_settings.erb"
    mode 0644
    owner "root"
    group "root"
    variables memstores: search(:node, "role:sprout AND chef_environment:#{node.chef_environment}"),
              remote_memstores: remote_memstores
  end
end

# Support clustering for homer and homestead
if node.roles.include? "cassandra"
  node_type = if node.run_list.include? "role[homer]"
                "homer"
              elsif node.run_list.include? "role[homestead]"
                "homestead"
              end
  cluster_name = node_type.capitalize + "Cluster"

  # Work out the other nodes in the geo-redundant cluster - we'll list all these
  # nodes as seeds.
  gr_index = gr_environments.index(node.chef_environment)
  gr_environment_search = gr_environments.map { |e| "chef_environment:" + e }.join(" OR ")
  gr_cluster_nodes = search(:node, "role:#{node_type} AND (#{gr_environment_search})")

  # Work out the other nodes in the local cluster - we'll calculate the token ID
  # based on these.
  cluster_nodes = search(:node, "role:#{node_type} AND chef_environment:#{node.chef_environment}")

  # Sort into "Cassandra order", where each node bisects the largest space
  # between previously inserted nodes.  If you do the sums you'll see that
  # this equates to ordering by the reverse of the binary representation of
  # the 0-indexed node index.
  cluster_nodes.sort_by! { |n| (n[:clearwater][:index] - 1).to_s(2).reverse }

  # Calculate our token by taking an even chunk of the token space.
  #
  # As of the "Lock, Stock and Two Smoking Barrels" release, the ordering policy
  # changed.  Unfortunately this means that upgrade fails from releases before then
  # to releases after (since `nodetool move` rejects moves to taken tokens).  To
  # resolve this, we shuffle every node 1 token step round the ring.  Further, we
  # shuffle round by the geo-redundant site index, to avoid conflicts between sites.
  index = cluster_nodes.index { |n| n.name == node.name }
  token = ((index * 2**127) / cluster_nodes.length) + 1 + gr_index

  # Create the Cassandra config and topology files
  template "/etc/cassandra/cassandra.yaml" do
    source "cassandra/cassandra.yaml.erb"
    mode "0644"
    owner "root"
    group "root"
    variables cluster_name: cluster_name,
              token: token,
              seeds: gr_cluster_nodes.map { |n| is_gr ? n.cloud.public_ipv4 : n.cloud.local_ipv4 },
              node: node,
              is_gr: is_gr
  end
  template "/etc/cassandra/cassandra-topology.properties" do
    source "cassandra/cassandra-topology.properties.erb"
    mode "0644"
    owner "root"
    group "root"
    variables gr_cluster_nodes: gr_cluster_nodes,
              is_gr: is_gr
  end

  if tagged?('clustered')
    # Node is already in the cluster, just move to the correct token
    execute "nodetool" do
      command "nodetool move #{token}"
      action :run
      not_if { node.clearwater.cassandra.token == token rescue false }
    end
  else
    # Node has never been clustered, clean up old state then restart Cassandra into the new cluster
    execute "monit" do
      command "monit unmonitor cassandra"
      user "root"
      action :run
    end

    service "cassandra" do
      pattern "jsvc.exec"
      service_name "cassandra"
      action :stop
    end

    directory "/var/lib/cassandra" do
      recursive true
      action :delete
    end

    directory "/var/lib/cassandra" do
      action :create
      mode "0755"
      owner "cassandra"
      group "cassandra"
    end

    service "cassandra" do
      pattern "jsvc.exec"
      service_name "cassandra"
      action :start
    end

    # It's possible that we might need to create the keyspace now.
    ruby_block "create keyspace and tables" do
      block do
        require 'cassandra-cql'

        # Cassandra takes some time to come up successfully, give it 1 minute (should be ample)
        db = nil
        60.times do
          begin
            db = CassandraCQL::Database.new('127.0.0.1:9160')
            break
          rescue ThriftClient::NoServersAvailable
            sleep 1
          end
        end

        fail "Cassandra failed to start in the cluster" unless db

        # Create the KeySpace and table(s), don't care if they already exist.
        #
        # For all of these requests, it's possible that the creating a
        # keyspace/table might take so long that the thrift client times out.
        # This seems to happen a lot when Cassandra has just booted, probably
        # it's still settling down or garbage collecting.  In any case, on a
        # transport exception we'll simply sleep for a second and retry.  The
        # interesting case is an InvalidRequest which means that the
        # keyspace/table already exists and we should stop trying to create it.
        if node_type == "homer"
          cql_cmds = ["CREATE KEYSPACE homer WITH strategy_class='org.apache.cassandra.locator.SimpleStrategy' AND strategy_options:replication_factor=2",
                      "USE homer",
                      "CREATE TABLE simservs (user text PRIMARY KEY, value text) WITH read_repair_chance = 1.0"]
        elsif node_type == "homestead"
          cql_cmds = ["CREATE KEYSPACE homestead_cache WITH strategy_class='org.apache.cassandra.locator.SimpleStrategy' AND strategy_options:replication_factor=2",
                      "USE homestead_cache",
                      "CREATE TABLE impi (private_id text PRIMARY KEY, digest_ha1 text) WITH read_repair_chance = 1.0",
<<<<<<< HEAD
                      "CREATE TABLE impu (public_id text PRIMARY KEY, ims_subscription_xml text) WITH read_repair_chance = 1.0",

                      "CREATE KEYSPACE homestead_provisioning WITH strategy_class='org.apache.cassandra.locator.SimpleStrategy' AND strategy_options:replication_factor=2",
                      "USE homestead_provisioning",
                      "CREATE TABLE implicit_registration_sets (irs_id uuid PRIMARY KEY) WITH read_repair_chance = 1.0",
                      "CREATE TABLE service_profiles (sp_id uuid PRIMARY KEY,  initialfiltercriteria text, irs uuid) WITH read_repair_chance = 1.0",
                      "CREATE TABLE public (public_id text PRIMARY KEY, publicidentity text, serviceprofile uuid) WITH read_repair_chance = 1.0",
=======
                      "CREATE TABLE impu (public_id text PRIMARY KEY, ims_subscription_xml text, initial_filter_criteria_xml text) WITH read_repair_chance = 1.0",
                      "CREATE KEYSPACE homestead_provisioning WITH strategy_class='org.apache.cassandra.locator.SimpleStrategy' AND strategy_options:replication_factor=2",
                      "USE homestead_provisioning",
                      "CREATE TABLE irs (irs_id uuid PRIMARY KEY,  ims_subscription_xml text) WITH read_repair_chance = 1.0",
                      "CREATE TABLE public (public_id text PRIMARY KEY, associated_irs uuid) WITH read_repair_chance = 1.0",
>>>>>>> geo_redundancy_to_merge
                      "CREATE TABLE private (private_id text PRIMARY KEY, digest_ha1 text) WITH read_repair_chance = 1.0"]
        end

        cql_cmds.each do |cql_cmd|
          begin
            db.execute(cql_cmd)
          rescue CassandraCQL::Thrift::Client::TransportException => e
            sleep 1
            retry
          rescue CassandraCQL::Error::InvalidRequestException
            # Pass
          end
        end
      end

      # To prevent conflicts during clustering, only homestead-1 or homer-1
      # will ever attempt to create Keyspaces.
      only_if { node[:clearwater][:index] == 1 }
      action :run
    end

    # Re-enable monitoring
    execute "monit" do
      command "monit monitor cassandra"
      user "root"
      action :run
    end
  end

  # Now we've migrated to our new token, remember it
  ruby_block "save cluster details" do
    block do
      node.set[:clearwater][:cassandra][:cluster] = cluster_name
      node.set[:clearwater][:cassandra][:token] = token
    end
    action :run
  end
end

# Now we're clustered
tag('clustered')
