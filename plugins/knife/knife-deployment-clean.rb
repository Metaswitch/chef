# @file knife-deployment-clean.rb
#
# Copyright (C) Metaswitch Networks 2014
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

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

      servers_to_terminate = connection.servers.all
      # Filter down to unnamed servers or those which have the correct
      # name for our environment
      servers_to_terminate.select!{ |s| s.tags["Name"].nil? or s.tags["Name"].split("-").first == config[:environment] }
      # Only delete nodes with roles contained in this whitelist
      whitelist = ["bono", "ellis", "homer", "homestead", "sprout", "ralf"]
      servers_to_terminate.select!{ |s| s.tags["Name"].nil? or whitelist.include? s.tags["Name"].split("-")[1] }


      # Construct list of valid Chef nodes
      chef_nodes = find_nodes(name: "#{config[:environment]}-*")
      # Chef nodes that have no roles are also broken
      chef_nodes.select!{ |n| not n[:roles].nil? }
      chef_node_ids = chef_nodes.map{ |n| n[:ec2][:instance_id] }
      chef_node_names = chef_nodes.map{ |n| n.name }

      # We should only clean servers up if they are in "stopped"
      # state, or if they are in "running" state but not being managed
      # by Chef.
      servers_to_terminate.select!{ |s| (s.state == "running" and not chef_node_ids.include? s.id) or (s.state == "stopped")}

      # Delete any remaining servers
      Chef::Log.info "Will delete following broken servers: #{servers_to_terminate.map{ |s| s.tags["Name"] or "UNNAMED" }}" unless servers_to_terminate.empty?
      servers_to_terminate.each do |server|
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
