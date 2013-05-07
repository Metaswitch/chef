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

module Clearwater
  class BoxManager
    Chef::Knife::Ec2ServerCreate.load_deps
    Chef::Knife::RackspaceServerCreate.load_deps
    Chef::Knife::OpenstackServerCreate.load_deps

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
        {:name => "bono", :security_groups => ["base", "bono"], :public_ip => true},
        {:name => "ellis", :security_groups => ["base", "ellis"], :public_ip => true},
        {:name => "homestead", :security_groups => ["base", "homestead"]},
        {:name => "homer", :security_groups => ["base", "homer"]},
        {:name => "sprout", :security_groups => ["base", "sprout"]},
        {:name => "ibcf", :security_groups => ["base", "ibcf", "bono"]},
        {:name => "dns", :security_groups => ["base", "dns"]},
        {:name => "cacti", :security_groups => ["base", "cacti"]},
        {:name => "sipp", :security_groups => ["base", "bono"], :public_ip => true},
        {:name => "enum", :security_groups => ["base", "enum"]}
      ]

    @@supported_roles = @@supported_boxes.map { |r| r[:name] }

    @@default_flavor = {
      ec2: "m1.small",
      openstack: "2",
      rackspace: "3"
    }

    @@default_image = {
      ec2: "ami-3d4ff254",
      openstack: "5da88e4f-418f-4c5f-b148-b625071f20e6", # dfw
      #openstack: "03a48e99-2824-40d8-a0aa-2a819b676d9e", # iad
      rackspace: "9dccea61-59f1-4f78-84ce-3d139c4dd40b"
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
      end
      # Note that by default Rackspace does not use ssh auth, however we use a
      # preconfigured image with the correct ssh key
      knife_create.config[:identity_file] = "#{@attributes["keypair_dir"]}/#{@attributes["keypair"]}.pem"
      knife_create.config[:ssh_user] = "ubuntu"

      # Box description
      knife_create.config[:flavor] = (options[:flavor] or @@default_flavor[@cloud])
      knife_create.config[:image] = (options[:image] or @@default_image[@cloud])
      # Work around issue in knife-ec2 parameters validation
      # Have submitted patch: https://github.com/felixpalmer/knife-ec2
      Chef::Config[:knife][:image] = (options[:image] or @@default_image[@cloud])

      # Cloud specific config
      if @cloud == :ec2
        knife_create.config[:region] = @attributes["region"]
        knife_create.config[:security_groups] = box[:security_groups].map { |sg| "#{@environment.name}-#{sg}" }
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
      # Timestamp the logs so, when a node fails to be created it's log file is not overwritten
      bootstrap_log_filename = File.join(log_folder, "#{knife_create.config[:chef_node_name]}-bootstrap-#{Time.now.to_i}.log")
      bootstrap_output = File.new(bootstrap_log_filename, "w")
      bootstrap_output.sync = true
      knife_create.ui = Chef::Knife::UI.new(bootstrap_output, STDERR, STDIN, knife_create.config)
      Chef::Log.info "Bootstrapping #{knife_create.config[:chef_node_name]}, logs can be found at #{bootstrap_log_filename}"

      # Do not keep more than 1000 log files
      log_files = Dir["#{log_folder}/*.log"].sort_by { |f| File.mtime(f) }
      log_files[0..-1000].each { |f| File.unlink(f) rescue nil }

      # Finally, create box
      knife_create.run
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
