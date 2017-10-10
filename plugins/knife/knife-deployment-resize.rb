# @file knife-deployment-resize.rb
#
# Copyright (C) Metaswitch Networks 2017
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

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
             description: "Number of #{node} nodes to launch"
    end

    option :seagull,
      :long => "--seagull <seagull package to install>",
      :description => "Installs a seagull node."

    option :fail_limit,
      :long => "--fail-limit FAIL_LIMIT",
      :default => 5,
      :description => "Number of failed node creates to tolerate before aborting",
      :proc => Proc.new { |arg| Integer(arg) rescue begin Chef::Log.error "--fail-limit must be an integer"; exit 2 end }

    option :subscribers,
      :long => "--subscribers SUBSCRIBER_COUNT",
      :description => "Ignore *-count arguments and scale to this many subs",
      :proc => (Proc.new do |arg|
        begin
          Integer(arg).to_f
        rescue
          Chef::Log.error "--subscribers must be an integer"
          exit 2
        end
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

    # Auto-scaling parameters
    #
    # Scaling limits calculated from scaling tests on m1.small EC2 instances.
    SCALING_LIMITS = { "bono" =>      { bhca: 200000, subs: 50000 },
                       "homer" =>     { bhca: 2300000, subs: 1250000 },
                       "homestead" => { bhca: 850000, subs: 5000000 },
                       "ralf" =>      { bhca: 850000, subs: 5000000 },
                       "sprout" =>    { bhca: 250000, subs: 250000 },
                       "ellis" =>     { bhca: Float::INFINITY, subs: Float::INFINITY }
    }

    # Estimated number of busy hour calls per subscriber.
    BHCA_PER_SUB = 2

    def parse_config(config, number_of_sites)
      count = Hash.new()
      array = []
      %w{bono ibcf homer homestead sprout sipp ralf vellum dime}.each do |node|
        if config["#{node}_count".to_sym]
          array = config["#{node}_count".to_sym].split(",").map { |s| s.to_i }
          if array.size != number_of_sites
            abort("Unsupported configuration, --#{node}-count inconsistent with num_gr_sites")
          else
            for i in 1..number_of_sites
              count["#{node}-site#{i}".to_sym] = array[i-1]
            end
          end
        end
      end
      return count
    end

    def get_current_counts(number_of_sites)
      result = Hash.new(0)
      %w{bono ellis ibcf homer homestead sprout sipp ralf seagull vellum dime}.each do |node|
        for i in 1..number_of_sites
          result["#{node}-site#{i}".to_sym] = find_nodes(roles: "chef-base", site: i, role: node).length
        end
      end
      return result
    end

    # An existing site must have at least one bono
    def adding_sites?(count, number_of_sites)
      result = false
      for i in 1..number_of_sites
        if count["bono-site#{i}".to_sym] == 0
          result = true
        end
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

    def calculate_box_counts(config)
      Chef::Log.info "Subscriber count given, calculating box counts automatically:"

      boxes = ["homer", "homestead", "sprout"]
      boxes << "bono" if config[:bono_count] > 0
      boxes << "ralf" if config[:ralf_count] > 0

      boxes.each do |role|
        count_using_bhca_limit = (config[:subscribers] * BHCA_PER_SUB / SCALING_LIMITS[role][:bhca]).ceil
        count_using_subs_limit = (config[:subscribers] / SCALING_LIMITS[role][:subs]).ceil
        config["#{role}_count".to_sym] = [count_using_bhca_limit, count_using_subs_limit, 1].max
        Chef::Log.info " - #{role}: #{config["#{role}_count".to_sym]}"
      end
    end

    def run
      Chef::Log.info "Managing deployment in environment: #{config[:environment]}"
      Chef::Log.info "Starting resize operation"

      if attributes["num_gr_sites"] && attributes["num_gr_sites"] > 1
        number_of_sites = attributes["num_gr_sites"]
      else
        number_of_sites = 1
      end

      # Check and parse config before we start
      count = parse_config(config, number_of_sites)

      # Calculate box counts from subscriber count
      calculate_box_counts(config) if config[:subscribers]

      # Initialize status object
      init_status(["bono", "ellis", "homer", "homestead", "sprout", "sipp", "ralf", "vellum", "dime"], ["seagull"])

      # Create security groups
      configure_security_groups(config, SecurityGroupsCreate)
      set_progress 10

      # Enumerate current box counts so we can compare the desired list
      old_counts = get_current_counts(number_of_sites)

      # Set up new box counts based on supplied config, or existing state.
      # If an essential node type currently has no boxes, make sure we
      # create one.
      seagull_count = (config[:seagull] ? 1 : 0)

      new_counts = get_current_counts(number_of_sites)
      new_counts["ellis-site1".to_sym] = 1
      for i in 1..number_of_sites
        new_counts["seagull-site#{i}".to_sym] = seagull_count || old_counts[:seagull]
        %w{bono homer sprout vellum dime}.each do |node|
          new_counts["#{node}-site#{i}".to_sym] = count["#{node}-site#{i}".to_sym] || [old_counts["#{node}-site#{i}".to_sym], 1].max
        end
        %w{ibcf sipp}.each do |node|
          new_counts["#{node}-site#{i}".to_sym] = count["#{node}-site#{i}".to_sym] || old_counts["#{node}-site#{i}".to_sym]
        end
      end

      # Confirm changes if there are any
      whitelist = ["bono", "ellis", "ibcf", "homer", "homestead", "sprout", "sipp", "ralf", "seagull", "vellum", "dime"]

      Chef::Log.debug "Old nodes: #{old_counts}"
      Chef::Log.debug "New nodes: #{new_counts}"

      confirm_changes(old_counts, new_counts, whitelist) unless old_counts == new_counts

      # Create boxes
      node_list = expand_hashes(new_counts)
      create_node_list = calculate_boxes_to_create(env, node_list)

      Chef::Log.info "Creating deployment nodes" unless create_node_list.empty?
      launch_boxes(create_node_list)
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
      clean_deployment config
      set_progress 70

      # Sleep to let chef catch up _sigh_
      sleep 10

      # Set the etcd_cluster value. Mark any files that already exist.
      Chef::Log.info "Initializing etcd cluster"
      %w{vellum}.each do |node|
        # Get the list of nodes and iterate over them adding the
        # etcd_cluster attribute
        cluster = find_nodes(roles: node)
        cluster.each do |s|
          s.set[:clearwater][:etcd_cluster] = true
          s.save
        end
      end

      # Run chef client to set up the etcd_cluster environment variable.
      trigger_chef_client(config[:cloud],
                          "chef_environment:#{config[:environment]}")

      # If we are adding new sites, we need to upload shared config in the new
      # sites.
      if adding_sites?(old_counts, number_of_sites)
        # Create and upload the shared configuration. This should just be done
        # on a single node in each site. We choose the first Vellum node.
        config_nodes = []
        for i in 1..number_of_sites
          node = find_nodes(roles: 'vellum', site: i, index: 1)
          config_nodes = config_nodes.concat(node)
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
      end

      Chef::Log.info "Sleeping for 90 seconds before updating DNS to allow cluster to synchronize..."
      sleep(90)

      # Shared config should be synchronized now, run chef-client one last time
      # to pick up the final state. In particular, this step is what creates
      # numbers on ellis (which can only happen after it's picked up the shared
      # config, so we want to do it as late as possible).
      #
      # We only need to do this on nodes we aren't about to delete.
      node_list = expand_hashes(new_counts)
      active_nodes = list_active_boxes(env.name, node_list, whitelist)
      query_string_nodes = active_nodes.map { |n| "name:#{n.name}" }.join " OR "
      query_string = "chef_environment:#{config[:environment]} AND (#{query_string_nodes})"
      trigger_chef_client(config[:cloud], query_string)

      sleep(10)

      # Setup DNS zone record
      configure_dns_zone(config, attributes)
      set_progress 95
      configure_dns(config, DnsRecordsCreate)
      set_progress 99

      Chef::Log.info "Finishing resize operation"

      # Delete quiesced boxes, either because it's safe to do so, or because we've
      # been forced.
      Chef::Log.info "Deleting quiesced boxes..."
      delete_quiesced_boxes env

    end
  end
end
