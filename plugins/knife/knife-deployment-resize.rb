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
require_relative 'boxes'

module ClearwaterKnifePlugins
  class DeploymentResize < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils

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

    %w{bono homestead homer sprout}.each do |node|
      option "#{node}_count".to_sym,
             long: "--#{node}-count #{node.upcase}_COUNT",
             default: 1,
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

    # Auto-scaling parameters
    #
    # Scaling limits calculated from scaling tests on m1.small EC2 instances.
    SCALING_LIMITS = { "bono" =>      { bhca: 200000, subs: 50000 },
                       "homer" =>     { bhca: 2300000, subs: 1250000 },
                       "homestead" => { bhca: 850000, subs: 5000000 },
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

    def delete_extra_boxes(env, box_list)
      box_list.map! { |b| node_name_from_definition(env, b[:role], b[:index]) }
      victims = find_nodes(roles: "clearwater-infrastructure")
      # Only delete nodes with roles contained in this whitelist
      whitelist = ["bono", "ellis", "homer", "homestead", "sprout"]
      victims.select! { |v| not (v.roles & whitelist).empty? }
      victims.select! { |v| not box_list.include? v.name }

      return if victims.empty?

      victims.each do |v|
        delete_box(v.name, env)
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
      %w{bono sprout ellis homer homestead}.each do |node|
        result[node.to_sym] = find_nodes(roles: "clearwater-infrastructure", role: node).length
      end
      return result
    end

    def confirm_changes(old, new)
      old_names = find_nodes.select { |n| n.roles.include? "clearwater-infrastructure" }
                            .map { |n| n.name }
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
        ui.msg "The following boxes will be deleted:"
        victim_boxes.each do |b|
          ui.msg " - #{b}"
        end
      end

      @to_be_clustered = []
      service_interruption = false
      subscribers_lost = false
      unless old[:sprout] == new[:sprout]
        service_interruption = true
        @to_be_clustered << :sprout
      end

      [:homer, :homestead].each do |n|
        unless old[n] == new[n]
          @to_be_clustered << n
        end
      end
      
      if service_interruption or subscribers_lost
        ui.msg "This resize will require re-clustering the following nodes types:"
        @to_be_clustered.each { |c| ui.msg " - #{c.to_s}" }
        ui.msg "This is a destructive operation:"
        ui.msg " - Service will be interrupted" if service_interruption
      end

      fail "Exiting on user request" unless continue?
    end

    def calculate_box_counts(config)
      Chef::Log.info "Subscriber count given, calculating box counts automatically:"
      %w{bono homer homestead sprout}.each do |role|
        count_using_bhca_limit = (config[:subscribers] * BHCA_PER_SUB / SCALING_LIMITS[role][:bhca]).ceil
        count_using_subs_limit = (config[:subscribers] / SCALING_LIMITS[role][:subs]).ceil
        config["#{role}_count".to_sym] = [count_using_bhca_limit, count_using_subs_limit, 1].max
        Chef::Log.info " - #{role}: #{config["#{role}_count".to_sym]}"
      end
    end

    def run
      Chef::Log.info "Creating deployment in environment: #{config[:environment]}"

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
      new_counts = { homestead: config[:homestead_count],
                     sprout: config[:sprout_count],
                     homer: config[:homer_count],
                     ellis: 1,
                     bono: config[:bono_count] }

      # Confirm changes if there are any
      confirm_changes(old_counts, new_counts) unless old_counts == new_counts

      # Create boxes
      node_list = create_cluster(new_counts)
      create_node_list = calculate_boxes_to_create(env, node_list)

      Chef::Log.info "Creating deployment nodes" unless create_node_list.empty?
      launch_boxes(create_node_list)
      set_progress 50

      delete_extra_boxes(env.name, node_list)
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

      # Cluster the nodes together if needed
      if old_counts != new_counts
        count_diffs = new_counts.merge(old_counts) { |k, v1, v2| v1 != v2 }
        Chef::Log.info "Reclustering nodes:"
        %w{sprout homer homestead}.each do |node|
          if count_diffs[node.to_sym]
            Chef::Log.info " - #{node}"
            box_cluster = BoxCluster.new("-E #{env.name}".split)
            box_cluster.config[:verbosity] = config[:verbosity]
            Chef::Config[:verbosity] = config[:verbosity]
            box_cluster.config[:cloud] = config[:cloud]
            box_cluster.name_args = [node]
            box_cluster.run
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

      # Setup DNS records defined above
      if config[:cloud] == :openstack
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
      set_progress 100
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

      ["bono", "ellis", "homer", "homestead", "sprout"].each do |node|
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
