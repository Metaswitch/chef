# @file knife-box-list.rb
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
      puts "No such node" if find_nodes(name: name_glob, roles: "clearwater-infrastructure").each do |node|
        if node[:ec2]
          print "Found node #{node.name} with instance-id "\
                            "#{node.ec2.instance_id} at "\
                            "#{node.cloud.public_hostname}"
        else
          print "Found node #{node.name} with hostname #{node.cloud.public_hostname} ip #{node.cloud.local_ipv4}"
        end
        puts node[:clearwater].include?("quiescing") ? " (quiescing since #{node[:clearwater]['quiescing']})" : ""

      end.empty?
    end
  end
end
