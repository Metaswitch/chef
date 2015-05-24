# @file deployments.rb
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

require 'chef'

module Clearwater
  class DeploymentManager
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

    # Node types that are controlled by the DeploymentManager
    NODE_TYPES = [ :bono, :homer, :homestead, :sprout, :ellis, :ibcf, :sipp ]

    # A PORO describing changes to be made
    class ChangeDescriptor
      # Arrays of NodeDescriptors to create/destroy
      attr_accessor :to_create, :to_destroy
    end

    # A description of a specific node to create/destroy
    class NodeDescriptor
      attr_accessor :env, :role, :index

      # Constructor for when you have a chef node in hand
      def self.from_chef_node(node)
        NodeDescriptor.new(node.chef_environment,
                           node.run_list.first.name,
                           node[:clearwater][:index])
      end

      # Standard constructor
      def initialize(env, role, index)
        @env = env
        @role = role
        @index = index
      end

      def to_s
        "#{@env}-#{@role}-#{@index}"
      end

      def hash
        to_s.hash
      end

      def eql? o
        to_s == o.to_s
      end

      def == o
        to_s == o.to_s
      end
    end

    def initialize(environment)
      @environment = environment
    end

    def create_by_counts(box_counts)
      resize_by_counts(box_counts)
    end

    def create_by_subs(subs)
      create_by_counts(calculate_box_counts(subs))
    end

    def resize_by_counts(box_counts)
      new_list = get_desired_list(box_counts)
      old_list = get_current_list
      changes = calculate_changes(new_list, old_list)
      confirm_changes(changes)
      apply_changes(changes)
    end

    def resize_by_subs(subs)
      resize_by_counts(calculate_box_counts(subs))
    end

private

    def calculate_box_counts(subs)
      puts "Subscriber count given, calculating box counts automatically:"
      SCALING_LIMITS.each_with_object({}) do |(role, scale), counts|
        count_using_bhca_limit = (subs * BHCA_PER_SUB / scale[:bhca]).ceil
        count_using_subs_limit = (subs / scale[:subs]).ceil
        counts[role.to_sym] = [count_using_bhca_limit, count_using_subs_limit, 1].max
        puts " - #{role}: #{counts[role.to_sym]}"
      end
    end

    def get_desired_list(box_counts)
      desired_list = []
      box_counts.each do |role, count|
        desired_list += (0..count-1).map do |i|
          NodeDescriptor.new(@environment, role, i + 1)
        end
      end
      desired_list
    end

    def get_current_list
      current_list = []
      NODE_TYPES.each do |role|
        current_list += find_nodes(role: role).map do |n|
          NodeDescriptor.from_chef_node(n)
        end
      end
      current_list
    end

    def calculate_changes(new_list, old_list)
      changes = ChangeDescriptor.new
      changes.to_create = new_list.select { |n| not old_list.include? n }
      changes.to_destroy = old_list.select { |n| not new_list.include? n }
      changes
    end

    def confirm_changes(changes)
      unless changes.to_create.empty?
        puts "The following boxes will be created:"
        changes.to_create.each do |b|
          puts " - #{b}"
        end
      end
      unless changes.to_destroy.empty?
        puts "The following boxes will be deleted:"
        changes.to_destroy.each do |b|
          puts " - #{b}"
        end
      end

      fail "Exiting on user request" unless continue?
    end

    def apply_changes(changes)
      fix_up_security_groups
      create_new_nodes(changes.to_create)
      destroy_old_nodes(changes.to_destroy)
      clean_deployment
      cluster_nodes
      fix_up_dns_records
    end

    ###########################################################################

    def find_nodes(options={})
      search(:node, query_string(true, options))
    end

    def query_string(add_env, options={})
      options[:chef_environment] ||= @environment if add_env
      options.map do |k,v|
        "#{k}:#{v}"
      end.join(" AND ")
    end

    def search(*args)
      @query_tool ||= Chef::Search::Query.new
      @query_tool.search(*args).first.compact
    end

    def continue? (prompt = "Continue?")
      true
    end
  end
end

