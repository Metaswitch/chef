# @file knife-box-list.rb
#
# Copyright (C) Metaswitch Networks 2016
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

require_relative 'knife-clearwater-utils'

module ClearwaterKnifePlugins
  class BoxList < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils

    banner "box list [NAME_GLOB]"

    deps do
      require 'chef'
      require 'fog'
    end

    def run()
      name_glob = name_args.first
      name_glob = "*" if name_glob == "" or name_glob.nil?
      puts "Searching for node #{name_glob} in #{env}..."
      nodes = find_nodes(name: name_glob, roles: "chef-base") + find_nodes(name: name_glob, roles: "cw_aio")
      puts "No such node" if nodes.each do |node|
        if node[:ec2]
          print "Found node #{node.name} with instance-id "\
                            "#{node.ec2.instance_id} at "\
                            "#{node.cloud.public_hostname}"
        else
          print "Found node #{node.name} with hostname #{node.cloud.public_hostname} ip #{node.cloud.local_ipv4}"
        end
        print " (quiescing since #{node[:clearwater]['quiescing']})" if node[:clearwater].include?("quiescing")
        puts ""

      end.empty?
    end
  end
end
