# @file knife-dnszone-create.rb
#
# Copyright (C) Metaswitch Networks
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

module ClearwaterKnifePlugins
  class DnszoneCreate < Chef::Knife
    banner "dnszone create DOMAIN"
    deps do
      require 'chef'
      require 'fog'
      require 'nokogiri'
    end
    def run
      unless name_args.size == 1
        ui.fatal "You need to supply a domain name"
        show_usage
        exit 1
      end
      # Get attributes
      def domain
        @domain = name_args.first + "."
      end

      # Get provider
      def dns
        @dns ||= Fog::DNS.new({
          :provider => "aws",
          :aws_access_key_id => Chef::Config[:knife][:aws_access_key_id],
          :aws_secret_access_key => Chef::Config[:knife][:aws_secret_access_key] 
        })
      end

      # Try to get the zone
      zone = dns.zones.all.select do |z|
        z.domain == domain
      end.first

      if zone.nil?
        # Create it
        zone = dns.zones.create(:domain => domain)
        puts "Zone created: #{zone.domain}"
        puts "Manual step required: should use nameservers #{zone.nameservers} for #{zone.domain}"
      else
        puts "Zone #{zone.domain} already exists, not creating"
      end
    end
  end
end
