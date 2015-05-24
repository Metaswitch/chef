# @file knife-box-delete.rb
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
require 'chef/knife/ec2_server_delete'
require 'chef/knife/rackspace_server_delete'
require 'chef/knife/openstack_server_delete'
Chef::Knife::Ec2ServerDelete.load_deps
Chef::Knife::RackspaceServerDelete.load_deps
Chef::Knife::OpenstackServerDelete.load_deps

module ClearwaterKnifePlugins
  class BoxDelete < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils
    banner "box delete [NAME_GLOB]"

    deps do
      require 'chef'
      require 'fog'
    end
    
    # Override the --yes parameter when invoking knife ec2 delete below, so that
    # CLI users of this tool are forced to double check what they are removing
    # Pass yes_allowed=true when invoking this plugin programmatically to permit
    # scripting without prompts
    def run(yes_allowed = false)
      name_glob = name_args.first 
      name_glob = "*" if name_glob == "" or name_glob.nil?

      puts "Searching for node #{name_glob} in #{env}..."
      # Protect against deleting nodes not created by Chef, eg dev boxes by requiring
      # that the role clearwater-infrastructure is present
      puts "No such node" unless not find_nodes(name: name_glob, roles: "clearwater-infrastructure").each do |node|
        provider = node[:cloud][:provider]
        fail "No provider found for node #{node.name}" if provider.nil?
        provider = provider.to_sym
        instance_id = node[provider][:instance_id]
        fail "No instance-id found for node #{node.name}" if instance_id.nil?
        puts "Found node #{node.name} with instance-id #{instance_id}"

        if provider == :ec2
          knife_delete = Chef::Knife::Ec2ServerDelete.new
        elsif provider == :openstack
          knife_delete = Chef::Knife::OpenstackServerDelete.new
        elsif provider == :rackspace
          knife_delete = Chef::Knife::RackspaceServerDelete.new
        end
        knife_delete.merge_configs
        knife_delete.config[:verbosity] = config[:verbosity]
        Chef::Config[:verbosity] = config[:verbosity]
        knife_delete.config[:purge] = true
        knife_delete.config[:chef_node_name] = node.name
        knife_delete.config[:yes] = yes_allowed and config[:yes]
        knife_delete.config[:region] = attributes["region"]
        knife_delete.name_args = [ instance_id ]
        knife_delete.run
      end.empty?
    end
  end
end
