# @file knife-deployment-utils.rb
#
# Copyright (C) Metaswitch Networks 2017
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

require_relative 'knife-clearwater-utils'
require_relative 'trigger-chef-client'
require_relative 'boxes'

module ClearwaterKnifePlugins
  module DeploymentUtils

    # Launch a single box. This will retry if the box fails to be created
    # (but not if anything else fails)
    def launch_box(box, environment, retries, supported_boxes)
      success = false

      loop do
        begin
          box_create = BoxCreate.new("-E #{environment}".split)
          box_create.name_args = [box[:role]]
          box_create.config[:index] = box[:index]
          box_create.config[:site] = box[:site]
          box_create.config[:verbosity] = config[:verbosity]
          Chef::Config[:verbosity] = config[:verbosity]
          box_create.config[:cloud] = config[:cloud]
          box_create.config[:seagull] = config[:seagull]
          box_create.config[:ralf] = (config[:ralf_count] and (config[:ralf_count].to_i > 0))
          box_create.run(supported_boxes)
        rescue Exception => e
          Chef::Log.error "Failed to create node: #{e}"
          Chef::Log.info e.backtrace
        end

        box_name = node_name_from_definition(environment, box[:role], box[:site], box[:index])
        Chef::Log.debug "Checking successful creation of #{box_name}"
        begin
          node = Chef::Node.load(box_name)
          if node.roles.include? box[:role]
            Chef::Log.info "Successfully created #{box_name}"
            break
          else
            Chef::Log.error "Failed to set roles for #{box_name}"
            delete_box(box_name, environment)
          end
        rescue
          Chef::Log.error "Failed to create node for #{box_name}"
          clean_up_broken_client(box_name, environment)
          @fail_count += 1
        end

        # Bail out if we've hit too many failures across the worker threads
        return false if @fail_count >= retries
      end

      return true
    end

    # Delete any broken clients
    def clean_up_broken_client(box_name, environment)
      client = find_clients(name: box_name)
      client.each do
        client_delete = Chef::Knife::ClientDelete.new
        client_delete.name_args = [box_name]
        client_delete.config[:yes] = true
        client_delete.config[:verbosity] = config[:verbosity]
        client_delete.run
      end
    end

    # Delete a box
    def delete_box(box_name, env)
      box_delete = BoxDelete.new("-E #{env}".split)
      box_delete.name_args = [box_name]
      box_delete.config[:yes] = true
      box_delete.config[:purge] = true
      box_delete.config[:verbosity] = config[:verbosity]
      Chef::Config[:verbosity] = config[:verbosity]
      box_delete.run()
    end

    # Launch boxes. This takes an optional array of supported box types
    # to launch
    def launch_boxes(box_list, supported_boxes = [])
      @fail_count = 0
      results = Parallel.map(box_list, in_threads: box_list.length) do |box|
        if @fail_count < config[:fail_limit]
          # Since we run this in an aggressively multi-threaded way, smear our start
          # times out randomly over a period of time, dependent on the number of
          # threads, to avoid spamming cloud provisioning APIs.
          sleep(rand * box_list.length)
          launch_box(box, config[:environment], config[:fail_limit], supported_boxes)
        else
          false
        end
      end

      abort_deployment if results.any? { |r| not r }
    end

    def in_stable_state? env
      transitioning_list = find_quiescing_nodes(env)
      return transitioning_list.empty?
    end

    def potential_deletions whitelist
      victims = find_nodes(roles: "chef-base")
      # Only delete nodes with roles contained in this whitelist
      victims.select! { |v| not (v.roles & whitelist).empty? }
      # Don't delete any AIO/AMI nodes
      victims.delete_if { |v| v.roles.include? "cw_aio" }
      return victims
    end

    def list_active_boxes(env, box_list, whitelist)
      boxes = potential_deletions whitelist
      box_names = box_list.map { |b| node_name_from_definition(env, b[:role], b[:site], b[:index]) }

      boxes.select! { |v| box_names.include? v.name }
      return boxes
    end

    def prepare_to_quiesce_extra_boxes(env, orig_box_list, whitelist)
      victims = potential_deletions whitelist
      box_list = orig_box_list.map { |b| node_name_from_definition(env, b[:role], b[:site], b[:index]) }

      victims.select! { |v| not box_list.include? v.name }

      return if victims.empty?

      victims.each do |v|
        prepare_to_quiesce_box(v.name, env)
      end
    end

    def quiesce_extra_boxes(env, box_list, whitelist)
      victims = potential_deletions whitelist
      box_list.map! { |b| node_name_from_definition(env, b[:role], b[:site], b[:index]) }

      victims.select! { |v| not box_list.include? v.name }

      return if victims.empty?

      victims.each do |v|
        quiesce_box(v.name, env)
      end
    end

    def delete_quiesced_boxes(env)
      record_manager = Clearwater::DnsRecordManager.new(attributes["root_domain"])

      quiesced_boxes = find_quiescing_nodes(env)
      record_manager.delete_node_records(quiesced_boxes)

      quiesced_boxes.each do |v|
        delete_box(v.name, env)
      end
    end

    def calculate_boxes_to_create(env, nodes)
      current_nodes = find_nodes(roles: "chef-base")

      result = nodes.select do |node|
        not current_nodes.any? { |cnode| cnode.name == node_name_from_definition(env, node[:role], node[:site], node[:index]) }
      end

      return result
    end

    def confirm_changes(old, new, whitelist)
      # Don't touch any AIO or AMI nodes
      old_names = potential_deletions(whitelist).map {|v| v.name}
      new_names = expand_hashes(new).map do |n|
        node_name_from_definition(env, n[:role], n[:site], n[:index])
      end
      create_boxes = new_names - old_names
      victim_boxes = old_names - new_names

      unless create_boxes.empty?
        ui.msg "The following boxes will be created:"
        create_boxes.each do |b|
          ui.msg " - #{b}"
        end
      end
      unless victim_boxes.empty?
        ui.msg "The following boxes will be quiesced:"
        victim_boxes.each do |b|
          ui.msg " - #{b}"
        end
      end

      fail "Exiting on user request" unless continue?
    end

    def clean_deployment config
      Chef::Log.info "Cleaning deployment..."
      deployment_clean = DeploymentClean.new("-E #{config[:environment]}".split)
      deployment_clean.config[:verbosity] = config[:verbosity]
      deployment_clean.config[:cloud] = config[:cloud]
      Chef::Config[:verbosity] = config[:verbosity]
      deployment_clean.run(yes_allowed=true)
    end

    def configure_security_groups(config, sg_class)
      status["Security Groups"][:status] = "Configuring..."
      Chef::Log.info "Creating security groups..."
      sg_create = sg_class.new("-E #{config[:environment]}".split)
      sg_create.config[:verbosity] = config[:verbosity]
      Chef::Config[:verbosity] = config[:verbosity]
      sg_create.run
      status["Security Groups"][:status] = "Done"
      Chef::Log.info "Creating security groups finished"
    end

    def configure_dns_zone(config, attributes)
      status["DNS"][:status] = "Configuring..."
      Chef::Log.info "Creating zone record..."
      zone_create = DnszoneCreate.new
      zone_create.config[:verbosity] = config[:verbosity]
      Chef::Config[:verbosity] = config[:verbosity]
      zone_create.name_args = [attributes["root_domain"]]
      zone_create.run
    end

    def configure_dns(config, dns_class)
      if config[:cloud].to_sym == :openstack
        Chef::Log.info "Creating BIND records..."
        bind_create = BindRecordsCreate.new("-E #{config[:environment]}".split)
        bind_create.config[:verbosity] = config[:verbosity]
        Chef::Config[:verbosity] = config[:verbosity]
        bind_create.run
        status["DNS"][:status] = "Done"
      else
        Chef::Log.info "Creating DNS records..."
        dns_create = dns_class.new("-E #{config[:environment]}".split)
        dns_create.config[:verbosity] = config[:verbosity]
        Chef::Config[:verbosity] = config[:verbosity]
        dns_create.run
        status["DNS"][:status] = "Done"
      end
    end

    # We create boxes in individual threads. This sets up the status for each
    # node thread, and an overall progress thread. These will be updated
    # by the set_progress function as the nodes are created
    def init_status(node_list, single_node_list)
      Thread.current[:progress] = 0
      Thread.current[:status] = {"Nodes" => {}}
      ["Security Groups", "DNS"].each do |item|
        Thread.current[:status][item] = {:status => "Pending"}
      end

      node_list.each do |node|
        Thread.current[:status]["Nodes"][node] =
          {:status => "Pending", :count => config["#{node}_count".to_sym]}
      end

      single_node_list.each do |node|
        Thread.current[:status]["Nodes"][node] =
          {:status => "Pending", :count => (config[node.to_sym] ? 1 : 0)}
      end
    end

    def set_progress(pct)
      Thread.current[:progress] = pct
    end

    def status
      Thread.current[:status]
    end

    def abort_deployment
      msg = "Too many failures (#{config[:fail_limit]}), aborting...
      To clean up broken boxes in deployment, issue:
      knife deployment clean -E #{config[:environment]}
      To delete the deployment completely, issue:
      knife deployment delete -E #{config[:environment]}"
      fail msg
    end
  end
end
