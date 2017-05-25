# @file knife-dns-records-create.rb
#
# Copyright (C) Metaswitch Networks
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

require_relative 'knife-clearwater-utils'

module ClearwaterKnifePlugins
  class DnsRecordsCreate < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils

    banner "knife dns records create -E ENV"

    deps do
      require 'chef'
      require 'fog'
      require 'nokogiri'
      require_relative 'dns-records'
      require_relative 'clearwater-dns-records'
    end

    def run
      nodes = find_nodes.select { |n| n.roles.include? "chef-base" }
      record_manager = Clearwater::DnsRecordManager.new(attributes["root_domain"])
      # Create node records e.g. bono-1
      record_manager.create_node_records(nodes, attributes)
      # Setup DNS records defined in clearwater-dns-records
      record_manager.create_or_update_deployment_records(dns_records, env.name, attributes)
    end
  end
end
