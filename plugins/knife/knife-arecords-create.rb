# @file knife-arecords-create.rb
#
# Copyright (C) Metaswitch Networks 2015
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

require_relative 'knife-clearwater-utils'

module ClearwaterKnifePlugins
  class ArecordsCreate < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils

    banner "knife arecords create -E ENV"

    deps do
      require 'chef'
      require 'fog'
      require 'nokogiri'
      require_relative 'dns-records'
    end

    def run
      record_manager = Clearwater::DnsRecordManager.new(attributes["root_domain"])
      find_nodes(roles: "chef-base").each do |node|
        options = {}
        options[:value] = [ node[:cloud][:public_ipv4] ]
        options[:type] = "A"
        options[:ttl] = attributes["dns_ttl"]
        options[:prefix] = env.name if attributes["use_subdomain"]
        subdomain = node.name.split("-")[1]
        subdomain += "-#{node[:clearwater][:index]}" if node[:clearwater][:index]
        record_manager.create_or_update_record(subdomain, options)
      end
    end
  end
end
