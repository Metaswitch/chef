# @file knife-cacti-update.rb
#
# Copyright (C) Metaswitch Networks
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

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
