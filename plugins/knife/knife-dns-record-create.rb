# @file knife-dns-record-create.rb
#
# Copyright (C) Metaswitch Networks 2013
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

require_relative 'knife-clearwater-utils'

module ClearwaterKnifePlugins
  class DnsRecordCreate < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils

    banner "knife dns record create SUBDOMAIN -z ZONE_ROOT -t TYPE <--value TARGET1,TARGET2|--local NODE_TYPE|--public NODE_TYPE>"

    deps do
      require 'chef'
      require 'fog'
      require 'nokogiri'
      require_relative 'dns-records'
    end

    option :prefix,
      :short => "-p PREFIX",
      :long => "--prefix PREFIX",
      :default => "",
      :description => "Prefix to apply to zone root"

    option :zone_root,
      :short => "-z ZONE_ROOT",
      :long => "--zone ZONE_ROOT",
      :description => "Zone root for record",
      :required => true

    option :type,
      :short => "-T TYPE",
      :long => "--type TYPE",
      :description => "Record type: A or CNAME",
      :required => true

    option :value,
      :long => "--value TARGET1,TARGET2",
      :description => "Target(s) to point DNS entry at",
      :proc => Proc.new { |l| l.split ","}

    option :local,
      :short => "-L QUERY_STRING",
      :long => "--local QUERY_STRING",
      :description => "Query string to find target(s) local IP addresses to point DNS entry at"

    option :public,
      :short => "-P QUERY_STRING",
      :long => "--public QUERY_STRING",
      :description => "Query string to find target(s) public IP addresses to point DNS entry at"

    option :ttl,
      :long => "--ttl TTL",
      :default => 3600,
      :description => "Time to live"

    def run
      unless name_args.size == 1
        ui.fatal "You need to supply a subdomain name"
        show_usage
        exit 1
      end
      
      if [config[:value], config[:local], config[:public]].compact.length != 1
        ui.fatal "Exactly one of --value, --local, or --public must be specified"
        show_usage
        exit 1
      end

      if not config[:local].nil?
        config[:value] = find_nodes(role: config[:local]).map {|n| n[:cloud][:local_ipv4]}
        if config[:value].empty?
          ui.fatal "--local #{config[:local]} did not match any nodes"
          show_usage
          exit 1
        end
      end

      if not config[:public].nil?
        config[:value] = find_nodes(role: config[:public]).map {|n| n[:cloud][:public_ipv4]}
        if config[:value].empty?
          ui.fatal "--public #{config[:public]} did not match any nodes"
          show_usage
          exit 1
        end
      end

      dns = Clearwater::DnsRecordManager.new(config[:zone_root])
      dns.create_or_update_record(name_args.first, config)
    end
  end
end
