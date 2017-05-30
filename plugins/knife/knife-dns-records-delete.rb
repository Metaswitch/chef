# @file knife-dns-records-delete.rb
#
# Copyright (C) Metaswitch Networks 2015
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

require_relative 'knife-clearwater-utils'

module ClearwaterKnifePlugins
  class DnsRecordsDelete < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils

    banner "knife dns records delete -E ENV"

    deps do
      require 'chef'
      require 'fog'
      require 'nokogiri'
      require_relative 'dns-records'
      require_relative 'clearwater-dns-records'
    end

    def run
      # Setup DNS records defined above
      record_manager = Clearwater::DnsRecordManager.new(attributes["root_domain"])
      record_manager.delete_deployment_records(dns_records, env.name, attributes)
      nodes = find_nodes.select { |n| n.roles.include? "chef-base" }
      record_manager.delete_node_records(nodes)
    end
  end
end
