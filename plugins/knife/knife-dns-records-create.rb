# @file knife-dns-records-create.rb
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
  class DnsRecordsCreate < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils

    banner "knife dns records create -E ENV"

    deps do
      require 'chef'
      require 'fog'
      require 'nokogiri'
      require_relative 'dns-records'
      require_relative 'clearwater-dns-records'
    end

    def run
      # Setup DNS records defined above
      record_manager = Clearwater::DnsRecordManager.new(attributes["root_domain"])
      record_manager.create_or_update_deployment_records(dns_records, env, attributes)
    end
  end
end
