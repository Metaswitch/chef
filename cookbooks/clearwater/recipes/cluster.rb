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

# Clustering for Sprout nodes
if node.run_list.include? "role[sprout]"
  sprouts = search(:node,
                   "role:sprout AND chef_environment:#{node.chef_environment}")
  sprouts.map! { |s| s.cloud.public_hostname }

  template "/etc/clearwater/cluster_settings" do
    source "cluster/cluster_settings.sprout.erb"
    mode 0440
    owner "root"
    group "root"
    variables nodes: sprouts
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

  # Work out the other nodes in the cluster
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
  # resolve this, we shuffle every node 1 token step round the ring.
  index = cluster_nodes.index { |n| n.name == node.name }
  token = ((index * 2**127) / cluster_nodes.length) + 1

  # Create the Cassandra config file
  template "/etc/cassandra/cassandra.yaml" do
    source "cassandra/cassandra.yaml.erb"
    mode 0440
    owner "root"
    group "root"
    variables cluster_name: cluster_name,
              token: token,
              seeds: cluster_nodes.map { |n| n.cloud.local_ipv4 },
              node: node
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
      mode "0700"
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
        begin
          db.execute("CREATE KEYSPACE #{node_type} WITH strategy_class='org.apache.cassandra.locator.SimpleStrategy' AND strategy_options:replication_factor=2")
        rescue CassandraCQL::Thrift::Client::TransportException => e
          sleep 1
          retry
        rescue CassandraCQL::Error::InvalidRequestException
          # Pass
        end

        db.execute("USE #{node_type}")
        if node_type == "homer"
          begin
            db.execute("CREATE TABLE simservs (user text PRIMARY KEY, value text)")
          rescue CassandraCQL::Thrift::Client::TransportException => e
            sleep 1
            retry
          rescue CassandraCQL::Error::InvalidRequestException
            # Pass
          end
        elsif node_type == "homestead"
          begin
            db.execute("CREATE TABLE filter_criteria (public_id text PRIMARY KEY, value text)")
          rescue CassandraCQL::Thrift::Client::TransportException => e
            sleep 1
            retry
          rescue CassandraCQL::Error::InvalidRequestException
            # Pass
          end

          begin
            db.execute("CREATE TABLE sip_digests (private_id text PRIMARY KEY, digest text)")
          rescue CassandraCQL::Thrift::Client::TransportException => e
            sleep 1
            retry
          rescue CassandraCQL::Error::InvalidRequestException
            # Pass
          end

          begin
            db.execute("CREATE TABLE public_ids (private_id text PRIMARY KEY)")
          rescue CassandraCQL::Thrift::Client::TransportException => e
            sleep 1
            retry
          rescue CassandraCQL::Error::InvalidRequestException
            # Pass
          end

          begin
            db.execute("CREATE TABLE private_ids (public_id text PRIMARY KEY)")
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
