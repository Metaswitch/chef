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
require_relative 'trigger-chef-client'
require_relative 'boxes'

module ClearwaterKnifePlugins
  class DeploymentResize < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils
    include ClearwaterKnifePlugins::TriggerChefClient

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

      # Since we run this in an aggressively multi-threaded way, smear our start
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
          box_create.config[:seagull] = config[:seagull]
          box_create.config[:ralf] = (config[:ralf_count] and (config[:ralf_count] > 0))
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
      whitelist = ["bono", "ellis", "ibcf", "homer", "homestead", "sprout", "sipp", "ralf", "seagull"]
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
      record_manager = Clearwater::DnsRecordManager.new(attributes["root_domain"])

      quiesced_boxes = find_quiescing_nodes(env)
      record_manager.delete_node_records(quiesced_boxes)

      quiesced_boxes.each do |v|
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
      %w{bono ellis ibcf homer homestead sprout sipp ralf seagull}.each do |node|
        result[node.to_sym] = find_nodes(roles: "clearwater-infrastructure", role: node).length
      end
      return result
    end

    def update_ralf_hostname environment, cloud
      ralfs = find_nodes(roles: "clearwater-infrastructure", role: "ralf").length

      changed_nodes = []

      %w{bono ibcf sprout ralf}.each do |node_type|
        find_nodes(roles: "clearwater-infrastructure", role: node_type).each do |node|
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
        ui.msg "The following boxes will be quiesced:"
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
      Chef::Log.info "Managing deployment in environment: #{config[:environment]}"
      Chef::Log.info "Starting resize operation"

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
        Chef::Log.info "Waiting 60s for DNS to propagate..."
        sleep 60
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
  
      # Set the etcd_cluster value. Mark any files that already exist.
      if old_counts.all? {|(node_type, count)| count == 0 }
        Chef::Log.info "Setting the etcd_cluster values"
        %w{sprout ralf homer homestead bono ellis}.each do |node|
          # Get the list of nodes and iterate over them adding the 
          # etcd_cluster attribute
          cluster = find_nodes(roles: node)
          cluster.each do |s|
            s.set[:clearwater][:etcd_cluster] = true
            s.save
          end
        end

        # Create and upload the shared configuration. This should just be done 
        # on a single node in the deployment. We choose the first Sprout
        sprouts = find_nodes(roles: 'sprout')
        sprouts.sort_by! { |n| n[:clearwater][:index] }

        domain = if node[:clearwater][:use_subdomain]
                    node.chef_environment + "." + node[:clearwater][:root_domain]
                 else
                   node[:clearwater][:root_domain]
                 end

        if node[:clearwater][:seagull]
          hss = "hss.seagull." + domain
          cdf = "cdf.seagull." + domain
        else
          hss = nil
          cdf = "cdf." + domain
        end

        ralf = if node[:clearwater][:ralf] and ((node[:clearwater][:ralf] == true) || (node[:clearwater][:ralf] > 0))
                 "ralf." + domain + ":10888"
               else
                 ""
               end

        enum = Resolv::DNS.open { |dns| dns.getaddress(node[:clearwater][:enum_server]).to_s } rescue nil
      
        template "/etc/clearwater/shared_config" do
        mode "0644"
        source "shared_config.erb"
        variables domain: domain,
                  node: node,
                  sprout: "sprout." + domain,
                  hs: "hs." + domain + ":8888",
                  hs_prov: "hs." + domain + ":8889",
                  homer: "homer." + domain + ":7888",
                  ralf: ralf,
                  cdf: cdf,
                  enum: enum,
                  hss: hss

        node = Chef::Node.load sprouts[0]
        hostname = node.cloud.public_hostname
        @ssh_key = File.join(attributes["keypair_dir"], "#{attributes["keypair"]}.pem")
        ssh_options = { keys: @ssh_key }

        # scp cannot copy directly to protected locations so use a temp file
        # TODO The names/locations/parameters? of the scripts need checking
        ssh.scp.upload! StringIO.new(data), "tmp"
        ssh.exec! "sudo mv tmp /etc/clearwater/shared_config"
        ssh.exec! "sudo chown root:root /etc/clearwater/shared_config"
        ssh.exec! "sudo chmod 644 /etc/clearwater/shared_config"
        ssh.exec! "upload_shared_config"
        ssh.exec! "upload_enum_json"
        ssh.exec! "upload_bgcf_json"
        ssh.exec! "upload_scscf_json"

        # Finally run chef-client over all nodes
        trigger_chef_client(config[:cloud],
                            "chef_environment:#{config[:environment]}")
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

      Chef::Log.info "Finishing resize operation"

      # Delete quiesced boxes, either because it's safe to do so, or because we've
      # been forced.
      Chef::Log.info "Deleting quiesced boxes..."
      delete_quiesced_boxes env

      update_ralf_hostname(config[:environment], config[:cloud].to_sym)
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
      ["seagull"].each do |node|
        Thread.current[:status]["Nodes"][node] =
          {:status => "Pending", :count => (config[:seagull] ? 1 : 0)}
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
