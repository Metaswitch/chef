# @file knife-cacti-update.rb
#
# Project Clearwater - IMS in the Cloud
# Copyright (C) 2015 Metaswitch Networks Ltd
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

module ClearwaterKnifePlugins
  class CactiUpdate < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils
    include ClearwaterKnifePlugins::TriggerChefClient

    deps do
      require 'chef'
      require 'fog'
    end

    banner "cacti update"

    def run()

      # For each Bono, Ralf, Sprout and SIPp node, set it up in Cacti and associate it with the
      # appropriately-named host template

      # Specify '|| /bin/true' so we don't bail out on a failure

      find_nodes(roles: "chef-base", role: "cacti").each do |cacti|
        find_nodes(roles: "chef-base", role: "bono").each do |node|
          run_command(options[:cloud], "chef_environment:#{env} AND name:#{cacti.name}", "sudo bash /usr/share/clearwater/cacti/add_device.sh #{node.cloud.local_ipv4} #{node.name} Bono || /bin/true")
        end

        find_nodes(roles: "chef-base", role: "ralf").each do |node|
          run_command(options[:cloud], "chef_environment:#{env} AND name:#{cacti.name}", "sudo bash /usr/share/clearwater/cacti/add_device.sh #{node.cloud.local_ipv4} #{node.name} Ralf || /bin/true")
        end

        find_nodes(roles: "chef-base", role: "sprout").each do |node|
          run_command(options[:cloud], "chef_environment:#{env} AND name:#{cacti.name}", "sudo bash /usr/share/clearwater/cacti/add_device.sh #{node.cloud.local_ipv4} #{node.name} Sprout || /bin/true")
        end

        find_nodes(roles: "chef-base", role: "sipp").each do |node|
          run_command(options[:cloud], "chef_environment:#{env} AND name:#{cacti.name}", "sudo bash /usr/share/clearwater/cacti/add_device.sh #{node.cloud.local_ipv4} #{node.name} SIPp || /bin/true")
        end

        find_nodes(roles: "chef-base", role: "homestead").each do |node|
          run_command(options[:cloud], "chef_environment:#{env} AND name:#{cacti.name}", "sudo bash /usr/share/clearwater/cacti/add_device.sh #{node.cloud.local_ipv4} #{node.name} Homestead || /bin/true")
        end

        find_nodes(roles: "chef-base", role: "dime").each do |node|
          run_command(options[:cloud], "chef_environment:#{env} AND name:#{cacti.name}", "sudo bash /usr/share/clearwater/cacti/add_device.sh #{node.cloud.local_ipv4} #{node.name} Dime || /bin/true")
        end

        find_nodes(roles: "chef-base", role: "vellum").each do |node|
          run_command(options[:cloud], "chef_environment:#{env} AND name:#{cacti.name}", "sudo bash /usr/share/clearwater/cacti/add_device.sh #{node.cloud.local_ipv4} #{node.name} Vellum || /bin/true")
        end
      end
    end
  end
end
