# @file boxes.rb
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

require_relative "security-groups"

module Clearwater
  class BoxManager
    Chef::Knife::Ec2ServerCreate.load_deps
    Chef::Knife::RackspaceServerCreate.load_deps
    Chef::Knife::OpenstackServerCreate.load_deps
    include Clearwater::SecurityGroups

    def initialize(cloud, environment, attributes, options = {})
      raise ArgumentError.new "cloud must be one of: #{@@supported_clouds.join ', '}. #{cloud} was passed" unless @@supported_clouds.include? cloud
      @cloud = cloud
      @environment = environment
      @attributes = attributes
      @options = options
    end

    @@supported_clouds = [
      :ec2,
      :openstack,
      :rackspace
    ]

    @@supported_boxes = [
        {:name => "clearwater-infrastructure", :security_groups => ["base"], :public_ip => true},
        {:name => "cw_aio", :security_groups => ["base", "cw_aio"], :public_ip => true},
        {:name => "cw_ami", :security_groups => ["base", "cw_aio"], :public_ip => true},
        {:name => "bono", :security_groups => ["base", "internal-sip", "bono"], :public_ip => true},
        {:name => "ellis", :security_groups => ["base", "ellis"], :public_ip => true},
        {:name => "homestead", :security_groups => ["base", "homestead"]},
        {:name => "homer", :security_groups => ["base", "homer"]},
        {:name => "sprout", :security_groups => ["base", "internal-sip", "sprout"]},
        {:name => "ibcf", :security_groups => ["base", "internal-sip", "ibcf", "bono"]},
        {:name => "ralf", :security_groups => ["base", "ralf"]},
        {:name => "dns", :security_groups => ["base", "dns"], :public_ip => true},
        {:name => "cacti", :security_groups => ["base", "cacti"], :public_ip => true},
        {:name => "sipp", :security_groups => ["base", "sipp"], :public_ip => true},
        {:name => "enum", :security_groups => ["base", "enum"], :public_ip => true},
        {:name => "plivo", :security_groups => ["base", "internal-sip", "plivo"], :public_ip => true},
        {:name => "openimscorehss", :security_groups => ["base", "hss"]},
        {:name => "mangelwurzel", :security_groups => ["base", "internal-sip"]},
        {:name => "seagull", :security_groups => ["base", "seagull"]},
      ]

    @@supported_roles = @@supported_boxes.map { |r| r[:name] }

    @@default_flavor = {
      ec2: "m1.small",
      openstack: "2",
      rackspace: "3"
    }

    @@default_image = {
      ec2: {
        "us-east-1" => "ami-d017b2b8",
        "us-west-1" => "ami-1fe6e95a",
        "us-west-2" => "ami-d9a1e6e9",
        "eu-west-1" => "ami-84f129f3",
        "ap-southeast-1" => "ami-96fda7c4",
        "ap-northeast-1" => "ami-e5be98e4",
        "ap-southeast-2" => "ami-4f274775",
        "sa-east-1" => "ami-5fbb1042",
        default: "ami-84f129f3"
      },
      openstack: {
        "dfw" => "5da88e4f-418f-4c5f-b148-b625071f20e6",
        "iad" => "03a48e99-2824-40d8-a0aa-2a819b676d9e",
        default: "5da88e4f-418f-4c5f-b148-b625071f20e6"
      },
      rackspace: {
        default: "9dccea61-59f1-4f78-84ce-3d139c4dd40b"
      }
    }

    def self.supported_clouds
      @@supported_clouds
    end

    def self.supported_roles
      @@supported_roles
    end

    def create_box(role, options)
      raise ArgumentError.new "role must be one of: #{@@supported_roles.join ', '}. #{role} was passed" unless @@supported_roles.include? role
      box = @@supported_boxes.select{ |b| b[:name] == role }.first
      if @cloud == :ec2
        knife_create = Chef::Knife::Ec2ServerCreate.new
      elsif @cloud == :openstack
        knife_create = Chef::Knife::OpenstackServerCreate.new
      elsif @cloud == :rackspace
        knife_create = Chef::Knife::RackspaceServerCreate.new
      end

      # Common cloud config
      knife_create.merge_configs
      knife_create.config[:environment] = @environment
      knife_create.config[:run_list] = ["role[#{role}]"]
      if options[:index]
        knife_create.config[:chef_node_name] = "#{@environment}-#{role}-#{options[:index]}"
        knife_create.config[:json_attributes] = {:clearwater => {:index => options[:index]}}
      else
        knife_create.config[:chef_node_name] = "#{@environment}-#{role}"
        knife_create.config[:json_attributes] = {:clearwater => {}}
      end
      # Note that by default Rackspace does not use ssh auth, however we use a
      # preconfigured image with the correct ssh key
      knife_create.config[:identity_file] = "#{@attributes["keypair_dir"]}/#{@attributes["keypair"]}.pem"
      knife_create.config[:ssh_user] = "ubuntu"

      # Box description
      knife_create.config[:flavor] = (options[:flavor] or @@default_flavor[@cloud])
      knife_create.config[:image] = (options[:image] or
                                     @@default_image[@cloud][@attributes["region"]] or
                                     @@default_image[@cloud][:default])
      # Work around issue in knife-ec2 parameters validation
      # Have submitted patch: https://github.com/felixpalmer/knife-ec2
      Chef::Config[:knife][:image] = knife_create.config[:image]

      # Cloud specific config
      if @cloud == :ec2
        knife_create.config[:region] = @attributes["region"]
        knife_create.config[:availability_zone] = "us-east-1b"
        knife_create.config[:security_group_ids] = box[:security_groups].map { |sg| translate_sg_to_id(@environment, "#{sg}-vpc-87f3d9e2") }
        knife_create.config[:subnet_id] = "subnet-9c148cc5"
        Chef::Config[:knife][:aws_ssh_key_id] = @attributes["keypair"]
      elsif @cloud == :openstack
        knife_create.config[:private_network] = true
        Chef::Config[:knife][:openstack_ssh_key_id] = "Clearwater"
        # TODO For now, using global security groups, unlike in ec2
        knife_create.config[:security_groups] = box[:security_groups].map { |sg| "cw-#{sg}" }
        knife_create.config[:floating_ip] = nil if box[:public_ip]
      end

      # Log the client response to a file, rather than to the screen
      log_folder = File.join(File.dirname(__FILE__), "..", "..", "logs")
      begin
        Dir::mkdir(log_folder)
      rescue SystemCallError => e
        raise unless FileTest::directory? log_folder
      end

      # Timestamp the logs so when a node fails to be created its log file is not overwritten
      bootstrap_log_filename = File.join(log_folder, "#{knife_create.config[:chef_node_name]}-bootstrap-#{Time.now.to_i}.log")
      bootstrap_output = File.new(bootstrap_log_filename, "w")
      bootstrap_output.sync = true
      knife_create.ui = Chef::Knife::UI.new(bootstrap_output, STDERR, STDIN, knife_create.config)
      Chef::Log.info "Bootstrapping #{knife_create.config[:chef_node_name]}, logs can be found at #{bootstrap_log_filename}"

      # Do not keep more than 1000 log files
      log_files = Dir["#{log_folder}/*.log"].sort_by { |f| File.mtime(f) }
      log_files[0..-1000].each { |f| File.unlink(f) rescue nil }

      # Node specific changes - Add memento role
      if role == "sprout" and @attributes["memento_enabled"] == "Y"
        knife_create.config[:run_list] += ["role[memento]"]
      end

      # Node specific changes - Add gemini role
      if role == "sprout" and @attributes["gemini_enabled"] == "Y"
        knife_create.config[:run_list] += ["role[gemini]"]
      end

      # Node specific changes - Add cdiv_as role
      if role == "sprout" and @attributes["cdiv_as_enabled"] == "Y"
        knife_create.config[:run_list] += ["role[call-diversion-as]"]
      end

      # Add ralf/seagull configuration - this will affect /etc/clearwater/config
      # on non-ralf/seagull nodes
      knife_create.config[:json_attributes][:clearwater][:seagull] = options[:seagull]
      knife_create.config[:json_attributes][:clearwater][:ralf] = options[:ralf]

      # Finally, create box
      require 'pry'
      binding.pry
      knife_create.run
      return knife_create.server
    end

    private

  end
end

# Monkey Patch the 'server create' plugin classes to pass it's UI object to the bootstrap class.
#
# Without this, we can't control the output of chef-client from the bootstrap.
require 'chef/knife/ec2_server_create'
class Chef::Knife::Ec2ServerCreate
  if not instance_methods.include? :old_bootstrap_for_node
    alias_method :old_bootstrap_for_node, :bootstrap_for_node

    def bootstrap_for_node(*args)
      bootstrap = old_bootstrap_for_node(*args)
      bootstrap.ui = ui
      bootstrap
    end
  end
end

require 'chef/knife/rackspace_server_create'
class Chef::Knife::RackspaceServerCreate
  if not instance_methods.include? :old_bootstrap_for_node
    alias_method :old_bootstrap_for_node, :bootstrap_for_node

    def bootstrap_for_node(*args)
      bootstrap = old_bootstrap_for_node(*args)
      bootstrap.ui = ui
      bootstrap
    end
  end
end

require 'chef/knife/openstack_server_create'
class Chef::Knife::OpenstackServerCreate
  if not instance_methods.include? :old_bootstrap_for_node
    alias_method :old_bootstrap_for_node, :bootstrap_for_node

    def bootstrap_for_node(*args)
      bootstrap = old_bootstrap_for_node(*args)
      bootstrap.ui = ui
      bootstrap
    end
  end
end

def prepare_to_quiesce_box(box_name, env)
  node = Chef::Node.load box_name
  node.set[:clearwater]['quiescing'] = DateTime.now
  node.save
end

def quiesce_box(box_name, env)
  # Runs SSH commands on box_name to quiesce it
  # @param [String] box_name the name of the box to quiesce (e.g.
  #   rkd-bono-1)
  node = Chef::Node.load box_name
  hostname = node.cloud.public_hostname
  @ssh_key = File.join(attributes["keypair_dir"], "#{attributes["keypair"]}.pem")
  ssh_options = { keys: @ssh_key }
  
  Net::SSH.start(hostname, "ubuntu", ssh_options) do |ssh|
    ssh.exec! "sudo monit unmonitor -g etcd"
    ssh.exec! "sudo monit unmonitor clearwater-config-manager"
    ssh.exec! "sudo monit unmonitor clearwater-cluster-manager"
    ssh.exec! "sudo service clearwater-etcd decommission"
    case node.run_list.first.name
    when "sprout"
      ssh.exec! "sudo monit unmonitor -g sprout"
      ssh.exec! "sudo service sprout start-quiesce"
    when "bono"
      ssh.exec! "sudo monit unmonitor -g bono"
      ssh.exec! "sudo service bono start-quiesce"
    end
  end
end

def find_quiescing_nodes(env)
  # Finds all nodes in env which are managed by Chef and which are quiescing
  # @param [String] env the Chef environment to use
  find_nodes(roles: "clearwater-infrastructure", chef_environment: env).select {|n| n[:clearwater].include? "quiescing"}
end

def find_active_nodes(role)
  # Finds all nodes in which have the given role and which are not quiescing
  # @param [String] role the Chef role to search for
  find_nodes(role: role).delete_if { |n| n[:clearwater].include? "quiescing"}
end
