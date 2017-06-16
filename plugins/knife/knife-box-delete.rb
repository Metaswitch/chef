# @file knife-box-delete.rb
#
# Copyright (C) Metaswitch Networks 2015
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

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
    
    def run()
      name_glob = name_args.first 
      name_glob = "*" if name_glob == "" or name_glob.nil?

      puts "Searching for node #{name_glob} in #{env}..."
      # Protect against deleting nodes not created by Chef, eg dev boxes by requiring
      # that the role chef-base is present
      puts "No such node" unless not find_nodes(name: name_glob, roles: "security").each do |node|
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
        knife_delete.config[:yes] = config[:yes]
        knife_delete.config[:region] = attributes["region"]
        knife_delete.name_args = [ instance_id ]
        knife_delete.run
      end.empty?
    end
  end
end
