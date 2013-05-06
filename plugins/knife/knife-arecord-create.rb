# @file knife-arecord-create.rb
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
      options[:prefix] = env.name if env.name != "_default"
      subdomain = role
      subdomain += "-#{config[:index]}" if config[:index]
      record_manager.create_or_update_record(subdomain, options)
    end
  end
end
