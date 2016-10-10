# @file knife-deployment-resize.rb
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
require_relative 'knife-deployment-utils'
require_relative 'trigger-chef-client'

module ClearwaterKnifePlugins
  class DeploymentResize < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils
    include ClearwaterKnifePlugins::TriggerChefClient
    include ClearwaterKnifePlugins::DeploymentUtils

    banner "knife deployment resize -E ENV"

    deps do
      require 'chef'
      require 'fog'
      require 'nokogiri'
      require 'parallel'
      require 'chef/knife/client_delete'
      require_relative 'dns-records'
      DnsRecordsCreate.load_deps
    end

    %w{bono homestead homer ibcf sprout sipp ralf vellum dime}.each do |node|
      option "#{node}_count".to_sym,
             long: "--#{node}-count #{node.upcase}_COUNT",
             description: "Number of #{node} nodes to launch",
             :proc => Proc.new { |arg| Integer(arg) rescue begin Chef::Log.error "--#{node}-count must be an integer"; exit 2 end }
    end

    option :seagull,
      :long => "--seagull <seagull package to install>",
      :description => "Installs a seagull node."

    option :fail_limit,
      :long => "--fail-limit FAIL_LIMIT",
      :default => 5,
      :description => "Number of failed node creates to tolerate before aborting",
      :proc => Proc.new { |arg| Integer(arg) rescue begin Chef::Log.error "--fail-limit must be an integer"; exit 2 end }

      end)

    option :cloud,
      :long => "--cloud CLOUD",
      :default => "ec2",
      :description => "Cloud to create box in. Currently support: #{Clearwater::BoxManager.supported_clouds.join ', '}",
      :proc => (Proc.new do |arg|
        unless Clearwater::BoxManager.supported_clouds.include? arg.to_sym
          Chef::Log.error "#{arg} is not a supported cloud"
          exit 2
        end
      end)

    option :start,
      :long => "--start",
      :description => "Starts a new resize operation."

    option :scscf_only,
      :long => "--scscf-only",
      :description => "Spins up the deployment with I-CSCF disabled."

    def get_current_counts
      result = Hash.new(0)
      %w{bono ellis ibcf homer homestead sprout sipp ralf seagull vellum dime}.each do |node|
        result[node.to_sym] = find_nodes(roles: "chef-base", role: node).length
      end
      return result
    end

    def update_ralf_hostname environment, cloud
      ralfs = find_nodes(roles: "chef-base", role: "ralf").length
      changed_nodes = []

      %w{bono ibcf sprout ralf dime}.each do |node_type|
        find_nodes(roles: "chef-base", role: node_type).each do |node|
          has_ralf = node[:clearwater][:ralf]
          Chef::Log.info "#{node.name}: ralf attribute is #{has_ralf} and number of ralfs is #{ralfs}"
          if (ralfs == 0) && has_ralf
            node.set[:clearwater][:ralf] = false
            node.save
            changed_nodes << node.name
          elsif (ralfs > 0) && (not has_ralf)
            node.set[:clearwater][:ralf] = true
            node.save
            changed_nodes << node.name
          end
        end
      end

      unless changed_nodes.empty?
        query_string_nodes = changed_nodes.map { |n| "name:#{n}" }.join " OR "
        query_string = "chef_environment:#{environment} AND (#{query_string_nodes})"
        trigger_chef_client(cloud, query_string, true)
      end
    end
	
	def report_progress stage
	puts "#{stage} at #{Time.new.to_f - @start_time}"

    def run
	  start_time = Time.new.to_f
      if (attributes["split_storage"] and attributes["gr"])
        abort("Unsupported configuration, split_storage and gr both true. Aborting process")
      end

      Chef::Log.info "Managing deployment in environment: #{config[:environment]}"
      Chef::Log.info "Starting resize operation"

      # Initialize status object
      init_status(["bono", "ellis", "homer", "homestead", "sprout", "sipp", "ralf", "vellum", "dime"], ["seagull"])

      # Create security groups
	  report_progress "About to configure security groups"
      configure_security_groups(config, SecurityGroupsCreate)
	  report_progress "Configured security groups"
      set_progress 10

      # Enumerate current box counts so we can compare the desired list
      old_counts = get_current_counts

      # Set up new box counts based on supplied config, or existing state.
      # If an essential node type currently has no boxes, make sure we
      # create one.
      seagull_count = (config[:seagull] ? 1 : 0)

      new_counts = {
        ellis: 1,
        bono: config[:bono_count] || [old_counts[:bono], 1].max,
        homestead: config[:homestead_count] || [old_counts[:homestead], 1].max,
        ralf: config[:ralf_count] || old_counts[:ralf],
        homer: config[:homer_count] || [old_counts[:homer], 1].max,
        sprout: config[:sprout_count] || [old_counts[:sprout], 1].max,
        ibcf: config[:ibcf_count] || old_counts[:ibcf],
        sipp: config[:sipp_count] || old_counts[:sipp],
        seagull: seagull_count || old_counts[:seagull] }
        if attributes["split_storage"]
          new_counts[:vellum] = config[:vellum_count] || [old_counts[:vellum], 1].max
          new_counts.delete(:homestead)
          new_counts.delete(:ralf)
          new_counts[:dime] = config[:dime_count] || [old_counts[:dime], 1].max
          config[:dime_count] = new_counts[:dime]
        end

      # Confirm changes if there are any
      whitelist = ["bono", "ellis", "ibcf", "homer", "homestead", "sprout", "sipp", "ralf", "seagull", "vellum", "dime"]
	  report_progress "Calculated new counts"
      confirm_changes(old_counts, new_counts, whitelist) unless old_counts == new_counts

      # Create boxes
      node_list = expand_hashes(new_counts)
      create_node_list = calculate_boxes_to_create(env, node_list)

      Chef::Log.info "Creating deployment nodes" unless create_node_list.empty?
	  report_progress "Started launching boxes"
      launch_boxes(create_node_list)
	  report_progress "Finished launching boxes"
      set_progress 50

      prepare_to_quiesce_extra_boxes(env.name, node_list, whitelist)

      if not in_stable_state? env
        Chef::Log.info "Removing nodes from DNS before quiescing..."
        configure_dns(config, DnsRecordsCreate)
        Chef::Log.info "Waiting 60s for DNS to propagate..."
        sleep 60
      end

      quiesce_extra_boxes(env.name, node_list, whitelist)
      set_progress 60

      # Now that all the boxes are in place, cleanup any that failed
	  report_progress "Cleaning deployment"
      clean_deployment config
      set_progress 70

      # Sleep to let chef catch up _sigh_
      sleep 10

	  report_progress "Starting to initialise etcd cluster"
      # Set the etcd_cluster value. Mark any files that already exist.
      if old_counts.all? {|node_type, count| count == 0 }
        Chef::Log.info "Initializing etcd cluster"

        if attributes["split_storage"]
          %w{vellum}.each do |node|
            # Get the list of nodes and iterate over them adding the
            # etcd_cluster attribute
            cluster = find_nodes(roles: node)
            cluster.each do |s|
              s.set[:clearwater][:etcd_cluster] = true
              s.save
            end
          end
        else
          %w{sprout ralf homer homestead bono ellis}.each do |node|
            # Get the list of nodes and iterate over them adding the
            # etcd_cluster attribute
            cluster = find_nodes(roles: node)
            cluster.each do |s|
              s.set[:clearwater][:etcd_cluster] = true
              s.save
            end
          end
        end
		report_progress "Finished initialising etcd cluster"

        # Run chef client to set up the etcd_cluster environment variable.
        trigger_chef_client(config[:cloud],
                            "chef_environment:#{config[:environment]}")
		report_progress "Finished running chef-client"

        # Create and upload the shared configuration. This should just be done
        # on a single node in each site. We choose the first Sprout or Vellum
        # node, depending on deployment architecture.
        if attributes["split_storage"]
          nodes = find_nodes(roles: 'vellum')
          nodes.sort_by! { |n| n[:clearwater][:index] }
          config_nodes = nodes[0..0]
        else
          nodes = find_nodes(roles: 'sprout')
          nodes.sort_by! { |n| n[:clearwater][:index] }
          if attributes["gr"]
            config_nodes = nodes[0..1]
          else
            config_nodes = nodes[0..0]
          end
        end

        for config_node in config_nodes
          config_node.run_list << "recipe[clearwater::shared_config]"

          if config[:scscf_only]
            config_node.set[:clearwater][:upstream_hostname] = "scscf.$sprout_hostname"
            config_node.set[:clearwater][:upstream_port] = 5054
            config_node.set[:clearwater][:icscf] = 0
          end

          config_node.save
        end

        query_strings = config_nodes.map { |n| "name:#{n.name}" }
        trigger_chef_client(config[:cloud],
                            "chef_environment:#{config[:environment]} AND (#{query_strings.join(" OR ")})")
		report_progress "Finished applying shared config"
      end

      Chef::Log.info "Sleeping for 90 seconds before updating DNS to allow cluster to synchronize..."
      sleep(90)

      # Shared config should be synchronized now, run chef-client one last time
      # to pick up the final state. In particular, this step is what creates
      # numbers on ellis (which can only happen after it's picked up the shared
      # config, so we want to do it as late as possible).
	  report_progress "Starting final chef-client"
      trigger_chef_client(config[:cloud],
                          "chef_environment:#{config[:environment]}")
	  report_progress "Finished final chef-client"

      sleep(10)

      # Setup DNS zone record
	  report_progress "Starting DNS configuration"
      configure_dns_zone(config, attributes)
      set_progress 95
      configure_dns(config, DnsRecordsCreate)
      set_progress 99
	  report_progress "Finished DNS configuration"

      Chef::Log.info "Finishing resize operation"

      # Delete quiesced boxes, either because it's safe to do so, or because we've
      # been forced.
      Chef::Log.info "Deleting quiesced boxes..."
      delete_quiesced_boxes env

      if not attributes["split_storage"]
        update_ralf_hostname(config[:environment], config[:cloud].to_sym)
      end
    end
  end
end
