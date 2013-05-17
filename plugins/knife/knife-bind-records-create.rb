# @file knife-bind-records-create.rb
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
      nodes = find_nodes.select { |n| n.roles.include? "clearwater-infrastructure" }
      domain = "#{env.name}.#{attributes["root_domain"]}"
      contact = "cw-ngv-admin.metaswitch.com"
      record_manager = Clearwater::DnsRecordManager.new(attributes["root_domain"])
      bind_manager = Clearwater::BindRecordManager.new(domain, contact)
      # Create NS record with route 53, pointing all queries for subdomain at 
      # our BIND server
      record_manager.create_or_update_record(nil, {
        prefix: env.name,
        type: "NS",
        value: "ns-#{env.name}.#{attributes["root_domain"]}",
        ttl: 300
      })
      record_manager.create_or_update_record("ns-#{env.name}", {
        prefix: nil,
        type: "A",
        value: "75.55.105.143",
        ttl: 300
      })
      # Configure records in BIND server
      bind_manager.create_or_update_records(dns_records, nodes)
    end
  end
end
