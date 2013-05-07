# @file knife-dnszone-create.rb
#
# Project Clearwater - IMS in the Cloud
# Copyright (C) 2013  Metaswitch Networks Ltd
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version, along with the "Special Exception" for use of
# the program along with SSL, set forth below. This program is distributed
# in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details. You should have received a copy of the GNU General Public
# License along with this program.  If not, see
# <http://www.gnu.org/licenses/>.
#
# The author can be reached by email at clearwater@metaswitch.com or by
# post at Metaswitch Networks Ltd, 100 Church St, Enfield EN2 6BQ, UK
#
# Special Exception
# Metaswitch Networks Ltd  grants you permission to copy, modify,
# propagate, and distribute a work formed by combining OpenSSL with The
# Software, or a work derivative of such a combination, even if such
# copying, modification, propagation, or distribution would otherwise
# violate the terms of the GPL. You must comply with the GPL in all
# respects for all of the code used other than OpenSSL.
# "OpenSSL" means OpenSSL toolkit software distributed by the OpenSSL
# Project and licensed under the OpenSSL Licenses, or a work based on such
# software and licensed under the OpenSSL Licenses.
# "OpenSSL Licenses" means the OpenSSL License and Original SSLeay License
# under which the OpenSSL Project distributes the OpenSSL toolkit software,
# as those licenses appear in the file LICENSE-OPENSSL.

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
