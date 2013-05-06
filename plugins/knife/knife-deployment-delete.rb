# @file knife-deployment-delete.rb
#
# Copyright (C) 2013  Metaswitch Networks Ltd
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# The author can be reached by email at clearwater@metaswitch.com or by post at
# Metaswitch Networks Ltd, 100 Church St, Enfield EN2 6BQ, UK

require_relative 'knife-clearwater-utils'
require_relative 'security-groups'

module ClearwaterKnifePlugins
  class DeploymentDelete < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils
    include Clearwater::SecurityGroups

    banner "knife deployment delete -E ENV"

    deps do
      require 'chef'
      require 'fog'
      require 'nokogiri'
      require_relative 'knife-box-create'
      require_relative 'knife-deployment-clean'
      require_relative 'knife-security-groups-create'
      require_relative 'clearwater-dns-records'
      require_relative 'clearwater-security-groups'
      require_relative 'dns-records'
    end

    def run
      Chef::Log.info "Deleting deployment in environment: #{config[:environment]}"
      ui.msg "Will destroy:"
      ui.msg " - Cluster DNS entries"
      ui.msg " - Box-specific DNS entries"
      find_nodes.select { |n| n.roles.include? "clearwater-infrastructure" }
                .each { |n| ui.msg " - #{n.name}" }
      fail "Exiting on user request" unless continue?

      Chef::Log.info "Deleting cluster DNS records..."
      dns_manager = Clearwater::DnsRecordManager.new(attributes["root_domain"])
      dns_manager.delete_deployment_records(dns_records, env)
      
      Chef::Log.info "Deleting node DNS entries..."
      nodes = find_nodes.select { |n| n.roles.include? "clearwater-infrastructure" }
      dns_manager.delete_node_records(nodes)

      Chef::Log.info "Deleting server instances..."
      box_delete = BoxDelete.new("-E #{env.name}".split)
      box_delete.config[:yes] = true
      box_delete.config[:verbosity] = config[:verbosity]
      box_delete.run(true)

      Chef::Log.warn "Not deleting security groups.  To trigger deletion, run:"
      Chef::Log.warn " - knife security groups delete -E #{env.name}"
    end
  end
end
