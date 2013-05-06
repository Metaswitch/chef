# @file knife-dns-record-delete.rb
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
