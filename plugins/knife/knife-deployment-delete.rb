# @file knife-deployment-delete.rb
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
      victims = find_nodes.select { |n| n.roles.include? "clearwater-infrastructure" and
                                        not n.roles.include? "cw_aio" }
                          .map { |n| n.name }
      victims.each { |n| ui.msg " - #{n}" }

      fail "Exiting on user request" unless continue?

      Chef::Log.info "Deleting cluster DNS records..."
      dns_manager = Clearwater::DnsRecordManager.new(attributes["root_domain"])
      dns_manager.delete_deployment_records(dns_records, env.name, attributes)
      if find_nodes(roles: "clearwater-infrastructure", role: "bono").length > 0
        dns_manager.delete_deployment_records(bono_dns_records, env.name, attributes)
      end

      Chef::Log.info "Deleting node DNS entries..."
      nodes = find_nodes.select { |n| n.roles.include? "clearwater-infrastructure" }
      dns_manager.delete_node_records(nodes)
      
      Chef::Log.info "Deleting server instances..."
      victims.each do |v|
        box_delete = BoxDelete.new("-E #{env.name}".split)
        box_delete.name_args = [v]
        box_delete.config[:yes] = true
        box_delete.config[:verbosity] = config[:verbosity]
        box_delete.run(true)
      end

      Chef::Log.warn "Not deleting security groups.  To trigger deletion, run:"
      Chef::Log.warn " - knife security groups delete -E #{env.name}"
    end
  end
end
