# @file knife-arecord-create.rb
#
# Copyright (C) Metaswitch Networks
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

require_relative 'knife-clearwater-utils'

module ClearwaterKnifePlugins
  class ArecordCreate < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils

    banner "knife arecord create ROLE_NAME"

    deps do
      require 'chef'
      require 'fog'
      require 'nokogiri'
      require_relative 'dns-records'
    end

    option :index,
      :long => "--index INDEX",
      :description => "Index of node to create, will be appended to the node name"

    def run
      unless name_args.size == 1
        ui.fatal "You need to supply a box role name"
        show_usage
        exit 1
      end
      role = name_args.first

      if config[:index]
        name = "#{config[:environment]}-#{role}-#{config[:index]}"
      else
        name = "#{config[:environment]}-#{role}"
      end

      node = find_nodes(name: name).first
      unless node
        ui.fatal "No matching node found for name #{name}"
        return
      end

      if node[:cloud][:public_ipv4].nil? or node[:cloud][:public_ipv4].empty?
        ui.fatal "Node #{name} has no public ip, not creating A record"
        return
      end

      record_manager = Clearwater::DnsRecordManager.new(attributes["root_domain"])
      options = {}
      options[:value] = node[:cloud][:public_ipv4]
      options[:type] = "A"
      options[:ttl] = attributes["dns_ttl"]
      options[:prefix] = env.name if attributes["use_subdomain"]
      subdomain = role
      subdomain += "-#{config[:index]}" if config[:index]
      record_manager.create_or_update_record(subdomain, options)
    end
  end
end
