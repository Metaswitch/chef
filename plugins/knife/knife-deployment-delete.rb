# @file knife-deployment-delete.rb
#
# Copyright (C) Metaswitch Networks 2015
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

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
      victims = find_nodes.select { |n| n.roles.include? "chef-base" and
                                        not n.roles.include? "cw_aio" }
                          .map { |n| n.name }
      victims.each { |n| ui.msg " - #{n}" }

      fail "Exiting on user request" unless continue?

      Chef::Log.info "Deleting cluster DNS records..."
      dns_manager = Clearwater::DnsRecordManager.new(attributes["root_domain"])
      dns_manager.delete_deployment_records(dns_records, env.name, attributes)

      Chef::Log.info "Deleting node DNS entries..."
      nodes = find_nodes.select { |n| n.roles.include? "chef-base" }
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
