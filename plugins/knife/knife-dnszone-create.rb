# @file knife-dnszone-create.rb
#
# Copyright (C) 2013  Metaswitch Networks Ltd
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# The author can be reached by email at clearwater@metaswitch.com or by post at
# Metaswitch Networks Ltd, 100 Church St, Enfield EN2 6BQ, UK

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
