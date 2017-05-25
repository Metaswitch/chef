# @file knife-bind-records-create.rb
#
# Copyright (C) Metaswitch Networks
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

require_relative 'knife-clearwater-utils'

module ClearwaterKnifePlugins
  class BindRecordsCreate < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils

    banner "knife bind records create -E ENV"

    deps do
      require 'chef'
      require 'fog'
      require 'nokogiri'
      require_relative 'bind-records'
      require_relative 'dns-records'
      require_relative 'clearwater-dns-records'
    end

    def run
      nodes = find_nodes.select { |n| n.roles.include? "chef-base" }
      domain = if attributes["use_subdomain"]
                 "#{env.name}.#{attributes["root_domain"]}"
               else
                 "#{attributes["root_domain"]}"
               end
      bind_server_public_ip = Chef::Config[:knife][:bind_server_public_ip]
      raise "Couldn't load BIND server IP, please configure knife[:bind_server_public_ip]" unless bind_server_public_ip
      record_manager = Clearwater::DnsRecordManager.new(attributes["root_domain"])
      bind_manager = Clearwater::BindRecordManager.new(domain, attributes)

      # Create NS record with route 53, pointing all queries for this deployment at 
      # the BIND server
      record_manager.create_or_update_record(nil, {
        prefix: attributes["use_subdomain"] ? env.name : nil,
        type: "NS",
        value: "ns-#{domain}",
        ttl: 300
      })
      record_manager.create_or_update_record(attributes["use_subdomain"] ? "ns-#{env.name}" : nil, {
        prefix: nil,
        type: "A",
        value: bind_server_public_ip,
        ttl: 300
      })
      # Configure records in BIND server
      bind_manager.create_or_update_records(dns_records, nodes)
    end
  end
end
