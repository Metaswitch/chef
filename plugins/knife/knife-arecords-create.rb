# @file knife-arecords-create.rb
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
      find_nodes(roles: "clearwater-infrastructure").each do |node|
        options = {}
        options[:value] = [ node[:cloud][:public_ipv4] ]
        options[:type] = "A"
        options[:ttl] = attributes["dns_ttl"]
        options[:prefix] = env.name if env.name != "_default"
        subdomain = node.name.split("-")[1]
        subdomain += "-#{node[:clearwater][:index]}" if node[:clearwater][:index]
        record_manager.create_or_update_record(subdomain, options)
      end
    end
  end
end
