# @file knife-box-quiesce.rb

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
  class BoxUnquiesce < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils
    banner "box quiesce [NAME_GLOB]"

    deps do
      require 'chef'
      require 'fog'
    end

    # Override the --yes parameter when invoking knife ec2 delete below, so that
    # CLI users of this tool are forced to double check what they are removing
    # Pass yes_allowed=true when invoking this plugin programmatically to permit
    # scripting without prompts
    def run(yes_allowed = false)
      name_glob = name_args.first
      name_glob = "*" if name_glob == "" or name_glob.nil?

      puts "Searching for node #{name_glob} in #{env}..."
      # Protect against deleting nodes not created by Chef, eg dev boxes by requiring
      # that the role clearwater-infrastructure is present
      puts "No such node" unless not find_nodes(name: name_glob, roles: "clearwater-infrastructure").each do |node|
        node.default[:clearwater].delete('quiescing')
        node.save

        case node.run_list.first.name
        when "sprout"
          puts "sprout SIGUSR1"
          #ssh monit sigquit
        when "bono"
          puts "bono SIGUSR1"
          #ssh monit sigquit
        when "homer"
          puts "stop homer"
          #ssh monit decommission
        when "homestead"
          puts "stop homestead"
          # ssh monit decommission
        else
          puts "can't unquiesce a box that you can't quiesce"
        end
      end.empty?
    end
  end
end
