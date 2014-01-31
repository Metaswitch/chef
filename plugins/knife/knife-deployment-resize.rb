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
require_relative 'cluster-boxes'
require_relative 'boxes'

module ClearwaterKnifePlugins
  class DeploymentResize < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils
    include ClearwaterKnifePlugins::ClusterBoxes

    banner "knife deployment resize -E ENV"

    deps do
      require 'chef'
      require 'fog'
      require 'nokogiri'
      require 'parallel'
      require 'chef/knife/client_delete'
      require_relative 'knife-box-create'
      require_relative 'knife-box-delete'
      require_relative 'knife-deployment-clean'
      require_relative 'knife-security-groups-create'
      require_relative 'knife-dnszone-create'
      require_relative 'knife-dns-records-create'
      require_relative 'knife-bind-records-create'
      require_relative 'dns-records'
      BoxCreate.load_deps
      DeploymentClean.load_deps
      DnsRecordsCreate.load_deps
      BindRecordsCreate.load_deps
    end

    %w{bono homestead homer ibcf sprout sipp ralf}.each do |node|
      option "#{node}_count".to_sym,
             long: "--#{node}-count #{node.upcase}_COUNT",
             description: "Number of #{node} nodes to launch",
             :proc => Proc.new { |arg| Integer(arg) rescue begin Chef::Log.error "--#{node}-count must be an integer"; exit 2 end }
    end

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

    option :finish,
      :long => "--finish",
      :description => "Finishes a previously started resize operation."

    option :force,
      :long => "--force",
      :description => "When used with --finish, finishes a previously started resize operation by destroying the nodes regardless of possible call failures or data loss. When used without --finish, destroys nodes immediately without requiring a separate --finish step."

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

    def launch_box(box, environment, retries)
      success = false

      # Since we run this in an agressively multi-threaded way, smear our start
      # times out randomly over a 5 second period to avoid spamming cloud
      # provisioning APIs.
      sleep(rand * 5)

      loop do
        begin
          box_create = BoxCreate.new("-E #{environment}".split)
          box_create.name_args = [box[:role]]
          box_create.config[:index] = box[:index]
          box_create.config[:verbosity] = config[:verbosity]
          Chef::Config[:verbosity] = config[:verbosity]
          box_create.config[:cloud] = config[:cloud]
          box_create.run
        rescue Exception => e
          Chef::Log.error "Failed to create node: #{e}"
          Chef::Log.debug e.backtrace
        end

        box_name = node_name_from_definition(environment, box[:role], box[:index])
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

    def delete_box(box_name, env)
      box_delete = BoxDelete.new("-E #{env}".split)
      box_delete.name_args = [box_name]
      box_delete.config[:yes] = true
      box_delete.config[:purge] = true
      box_delete.config[:verbosity] = config[:verbosity]
      Chef::Config[:verbosity] = config[:verbosity]
      box_delete.run(true)
    end

    def launch_boxes(box_list)
      @fail_count = 0
      results = Parallel.map(box_list, in_threads: box_list.length) do |box|
        if @fail_count < config[:fail_limit]
          launch_box(box, config[:environment], config[:fail_limit])
        else
          false
        end
      end

      abort_deployment if results.any? { |r| not r }
    end

    def potential_deletions
      victims = find_nodes(roles: "clearwater-infrastructure")
      # Only delete nodes with roles contained in this whitelist
      whitelist = ["bono", "ellis", "ibcf", "homer", "homestead", "sprout", "sipp", "ralf"]
      victims.select! { |v| not (v.roles & whitelist).empty? }
      # Don't delete any AIO/AMI nodes
      victims.delete_if { |v| v.roles.include? "cw_aio" }
      return victims
    end

    def in_stable_state? env
      transitioning_list = find_quiescing_nodes(env)
      return transitioning_list.empty?
    end

    def prepare_to_quiesce_extra_boxes(env, orig_box_list)
      victims = potential_deletions
      box_list = orig_box_list.map { |b| node_name_from_definition(env, b[:role], b[:index]) }

      victims.select! { |v| not box_list.include? v.name }

      return if victims.empty?

      victims.each do |v|
        prepare_to_quiesce_box(v.name, env)
      end
    end

    def quiesce_extra_boxes(env, box_list)
      victims = potential_deletions
      box_list.map! { |b| node_name_from_definition(env, b[:role], b[:index]) }

      victims.select! { |v| not box_list.include? v.name }

      return if victims.empty?

      victims.each do |v|
        quiesce_box(v.name, env)
      end
    end

    def delete_quiesced_boxes(env)
      find_quiescing_nodes(env).each do |v|
        delete_box(v.name, env)
      end
    end

    def unquiesce_boxes(env)
      find_quiescing_nodes(env).each do |v|
        unquiesce_box(v.name, env)
      end
    end

    def calculate_boxes_to_create(env, nodes)
      current_nodes = find_nodes(roles: "clearwater-infrastructure")

      result = nodes.select do |node|
        not current_nodes.any? { |cnode| cnode.name == node_name_from_definition(env, node[:role], node[:index]) }
      end

      return result
    end

    def node_name_from_definition(environment, role, index)
      "#{environment}-#{role}-#{index}"
    end

    def get_current_counts
      result = Hash.new(0)
      %w{bono ellis ibcf homer homestead sprout sipp ralf}.each do |node|
        result[node.to_sym] = find_nodes(roles: "clearwater-infrastructure", role: node).length
      end
      return result
    end

    def confirm_changes(old, new)
      # Don't touch any AIO or AMI nodes
      old_names = potential_deletions.map {|v| v.name}
      new_names = create_cluster(new).map do |n|
        node_name_from_definition(env, n[:role], n[:index])
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
        ui.msg "The following boxes will be quiesced (run 'knife deployment resize -E <env> --finish' afterwards to terminate them):"
        victim_boxes.each do |b|
          ui.msg " - #{b}"
        end
      end

      fail "Exiting on user request" unless continue?
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
      Chef::Log.info "Creating deployment in environment: #{config[:environment]}"

      if config[:finish]
        # Finishing an earlier started resize.

        # Check no incompatible options are specified.
        bad_options = []
        %w{bono homestead homer ibcf sprout sipp ralf}.each do |node|
          if config["#{node}_count".to_sym]
            bad_options << "--#{node}_count"
          end
        end
        if config[:subscribers]
          bad_options << "--subscribers"
        end

        if not bad_options.empty?
          puts "Cannot specify --finish option with #{bad_options.join("/")}"
          return
        end

        # Check to see if any quiescing boxes have finished quiescing
        if not config[:force]
          still_quiescing = find_incomplete_quiescing_nodes env
        end

        if config[:force] or still_quiescing.empty?
          # Safe to delete quiesced boxes.
          Chef::Log.info "Deleting quiesced boxes..."
          delete_quiesced_boxes env
        else
          puts "#{still_quiescing} are still quiescing, can't finish (use --force to force it at the risk of data loss or call failures)'"
        end

        # Clear the "joining" attribute on all the sprouts, homers and
        # homesteads and recluster them.
        # This is a bit of a hack for now, and will probably be
        # removed when we migrate this function to the node and make
        # it happen automatically.
        %w{sprout ralf homer homestead}.each do |role|
          cluster = find_nodes(roles: role)
          cluster.each do |node|
            node.set[:clearwater].delete(:joining)
            node.save
          end
          cluster_boxes(role, config[:cloud].to_sym)
        end

        return
      end

      # Calculate box counts from subscriber count
      calculate_box_counts(config) if config[:subscribers]

      # Initialize status object
      init_status

      # Create security groups
      status["Security Groups"][:status] = "Configuring..."
      Chef::Log.info "Creating security groups..."
      sg_create = SecurityGroupsCreate.new("-E #{config[:environment]}".split)
      sg_create.config[:verbosity] = config[:verbosity]
      Chef::Config[:verbosity] = config[:verbosity]
      sg_create.run
      status["Security Groups"][:status] = "Done"
      set_progress 10

      # Enumerate current box counts so we can compare the desired list
      old_counts = get_current_counts

      # Set up new box counts based on supplied config, or existing state.
      # If an essential node type currently has no boxes, make sure we
      # create one.
      new_counts = {
        ellis: 1,
        bono: config[:bono_count] || [old_counts[:bono], 1].max,
        homestead: config[:homestead_count] || [old_counts[:homestead], 1].max,
        ralf: config[:ralf_count] || old_counts[:ralf],
        homer: config[:homer_count] || [old_counts[:homer], 1].max,
        sprout: config[:sprout_count] || [old_counts[:sprout], 1].max,
        ibcf: config[:ibcf_count] || old_counts[:ibcf],
        sipp: config[:sipp_count] || old_counts[:sipp] }

      if not in_stable_state? env
        if old_counts == new_counts
          unquiesce_boxes(env)
          return
        else
          puts 'Error - you still have quiescing boxes in this deployment, so cannot perform a resize operation (other than returning the deployment to its original state). Please call "knife deployment resize -E <env> --finish" to try and complete this quiescing phase. You can see which boxes are quiescing with "knife box list -E env"'
          return
        end
      end

      # Confirm changes if there are any
      confirm_changes(old_counts, new_counts) unless old_counts == new_counts

      # Create boxes
      node_list = create_cluster(new_counts)
      create_node_list = calculate_boxes_to_create(env, node_list)

      Chef::Log.info "Creating deployment nodes" unless create_node_list.empty?
      launch_boxes(create_node_list)
      set_progress 50

      prepare_to_quiesce_extra_boxes(env.name, node_list)

      if not in_stable_state? env
        Chef::Log.info "Removing nodes from DNS before quiescing..."
        configure_dns config
        Chef::Log.info "Waiting 10 minutes for DNS to propagate..."
        sleep 600
      end

      quiesce_extra_boxes(env.name, node_list)
      set_progress 60

      # Now that all the boxes are in place, cleanup any that failed
      Chef::Log.info "Cleaning deployment..."
      deployment_clean = DeploymentClean.new("-E #{config[:environment]}".split)
      deployment_clean.config[:verbosity] = config[:verbosity]
      deployment_clean.config[:cloud] = config[:cloud]
      Chef::Config[:verbosity] = config[:verbosity]
      deployment_clean.run(yes_allowed=true)
      set_progress 70

      # Sleep to let chef catch up _sigh_
      sleep 10

      # If spinning up a new sprout, homer or homestead nodes in an existing cluster mark the
      # new ones so we know they are joining an existing cluster.
      %w{sprout ralf homer homestead}.each do |node|
        if old_counts[node.to_sym] != 0 and new_counts[node.to_sym] > old_counts[node.to_sym]
          # Get the list of sprouts ordered by index
          cluster = find_nodes(roles: node)
          cluster.sort_by! { |n| n[:clearwater][:index] }

          # Iterate over the new sprouts adding the joining attribute
          cluster.drop(old_counts[node.to_sym]).each do |s|
            s.set[:clearwater][:joining] = true
            s.save
          end
        end
      end

      # Cluster the nodes together if needed
      if old_counts != new_counts
        count_diffs = new_counts.merge(old_counts) { |k, v1, v2| v1 != v2 }
        Chef::Log.info "Reclustering nodes:"
        %w{sprout ralf homer homestead}.each do |node|
          if count_diffs[node.to_sym]
            Chef::Log.info " - #{node}"
            cluster_boxes(node, config[:cloud].to_sym)
          end
        end
      end

      # Setup DNS zone record
      status["DNS"][:status] = "Configuring..."
      Chef::Log.info "Creating zone record..."
      zone_create = DnszoneCreate.new
      zone_create.config[:verbosity] = config[:verbosity]
      Chef::Config[:verbosity] = config[:verbosity]
      zone_create.name_args = [attributes["root_domain"]]
      zone_create.run
      set_progress 95

      configure_dns config
      set_progress 99

      if config[:force]
        # Destroy our quiescing boxes now rather than having a
        # separate --finish step
        delete_quiesced_boxes env
      end

    end

    def configure_dns config
      # Setup DNS records defined above
      if config[:cloud].to_sym == :openstack
        Chef::Log.info "Creating BIND records..."
        bind_create = BindRecordsCreate.new("-E #{config[:environment]}".split)
        bind_create.config[:verbosity] = config[:verbosity]
        Chef::Config[:verbosity] = config[:verbosity]
        bind_create.run
        status["DNS"][:status] = "Done"
      else
        Chef::Log.info "Creating DNS records..."
        dns_create = DnsRecordsCreate.new("-E #{config[:environment]}".split)
        dns_create.config[:verbosity] = config[:verbosity]
        Chef::Config[:verbosity] = config[:verbosity]
        dns_create.run
        status["DNS"][:status] = "Done"
      end
    end

    # Expands out hashes of boxes, e.g. {:bono => 3} becomes:
    # {{:role => "bono", :index => 1}, {:role => "bono", :index = 2}, etc...
    def create_cluster(boxes)
      boxes.map {|box, n| (1..n).map {|i| {:role => box.to_s, :index => i}}}.flatten
    end

    def init_status
      Thread.current[:progress] = 0
      Thread.current[:status] = {"Nodes" => {}}
      ["Security Groups", "DNS"].each do |item|
        Thread.current[:status][item] = {:status => "Pending"}
      end

      ["bono", "ellis", "homer", "homestead", "sprout", "sipp", "ralf"].each do |node|
        Thread.current[:status]["Nodes"][node] =
          {:status => "Pending", :count => config["#{node}_count".to_sym]}
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
