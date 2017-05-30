# @file knife-dns-record-delete.rb
#
# Copyright (C) Metaswitch Networks 2013
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

module ClearwaterKnifePlugins
  class DnsRecordDelete < Chef::Knife

    banner "knife dns record delete SUBDOMAIN --zone ZONE_ROOT --type TYPE [--prefix PREFIX]"

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

    def run
      unless name_args.size == 1
        ui.fatal "You need to supply a subdomain name"
        show_usage
        exit 1
      end
      
      dns = Clearwater::DnsRecordManager.new(config[:zone_root])
      dns.delete_record(name_args.first, config)
    end
  end
end
