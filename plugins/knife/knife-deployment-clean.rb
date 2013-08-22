# @file knife-deployment-clean.rb
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

require_relative 'knife-clearwater-utils'
require_relative 'boxes'
require 'chef/knife'

module ClearwaterKnifePlugins
  class DeploymentClean < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils

    # The clean command searches for boxes in a deployment that are not
    # controlled by Chef. These are left behind when a Chef bootstrap fails,
    # usually becausae of a bug in the debian package, but occasionally due
    # to a transient error, e.g. network issue when pulling a package
    banner "knife deployment clean -E ENV"

    deps do
      require 'chef'
      require 'fog'
      require 'parallel'
      require 'chef/knife/ec2_server_delete'
      Chef::Knife::Ec2ServerDelete.load_deps
    end

    option :cloud,
      :long => "--cloud CLOUD",
      :default => "ec2",
      :description => "Cloud to clean. Currently support ec2 only"

    # Override the --yes parameter when invoking knife ec2 delete below, so that
    # CLI users of this tool are forced to double check what they are removing
    # Pass yes_allowed=true when invoking this plugin programmatically to permit
    # scripting without prompts
    def run(yes_allowed = false)
      # TODO - Currently only support cleaning on ec2
      unless config[:cloud] == "ec2"
        msg =  "Cleaning is not supported for #{config[:cloud]} cloud"
        Chef::Log.info msg
        ui.msg msg
        return
      end

      # Only delete nodes with roles contained in this whitelist
      whitelist = ["bono", "ellis", "homer", "homestead", "sprout"]
      servers = connection.servers.all
      # Only care about running servers (Fog will also report recently terminated etc)
      servers.select!{ |s| s.state == "running" }
      # Filter down to unnamed servers or those which have the correct name for our environment
      servers.select!{ |s| s.tags["Name"].nil? or s.tags["Name"].split("-").first == config[:environment] }
      # Filter using whitelist
      servers.select!{ |s| s.tags["Name"].nil? or whitelist.include? s.tags["Name"].split("-")[1] }
      
      # Construct list of valid Chef nodes
      chef_nodes = find_nodes(name: "#{config[:environment]}-*")
      # Chef nodes that have no roles are also broken
      chef_nodes.select!{ |n| not n[:roles].nil? }
      chef_node_ids = chef_nodes.map{ |n| n[:ec2][:instance_id] }
      chef_node_names = chef_nodes.map{ |n| n.name }
      
      # Filter out servers which are controlled by Chef from the server list
      servers.select!{ |s| not chef_node_ids.include? s.id }
      
      # Delete any remaining servers
      Chef::Log.info "Will delete following broken servers: #{servers.map{ |s| s.tags["Name"] or "UNNAMED" }}" unless servers.empty?
      servers.each do |server|
        box_name = server.tags["Name"]
        Chef::Log.info "Found broken box #{box_name}"
        knife_ec2_delete = Chef::Knife::Ec2ServerDelete.new
        knife_ec2_delete.merge_configs
        knife_ec2_delete.config[:verbosity] = config[:verbosity]
        Chef::Config[:verbosity] = config[:verbosity]
        # If the box is not a valid Chef node, purge it from Chef. We can't simply do this for every
        # box, as there may be duplicately named boxes, some broken and some functioning - and we
        # do not want to delete the client & node from Chef if they are valid
        unless chef_node_names.include? box_name or box_name.nil?
          Chef::Log.info "#{box_name} is not a valid Chef node, will attempt to purge client & node from Chef"
          knife_ec2_delete.config[:purge] = true
          knife_ec2_delete.config[:chef_node_name] = box_name
        end
        knife_ec2_delete.config[:yes] = yes_allowed and config[:yes]
        knife_ec2_delete.config[:region] = attributes["region"]
        knife_ec2_delete.name_args = [ server.id ]
        knife_ec2_delete.run
      end
    end

    def connection
      @connection ||= begin
        connection = Fog::Compute.new(
          :provider => "aws",
          :aws_access_key_id => Chef::Config[:knife][:aws_access_key_id],
          :aws_secret_access_key => Chef::Config[:knife][:aws_secret_access_key],
          :region => attributes["region"]
        )
      end
    end
  end
end
