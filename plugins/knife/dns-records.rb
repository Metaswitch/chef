# @file dns-records.rb
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

module Clearwater
  class DnsRecordManager
    # Options may optionally be specified at create time and overwritten for each record created.
    def initialize(zone_root, options = {})
      @options = options
      @options[:zone_root] = zone_root
    end

    # Converge on the specified DNS entry
    def create_or_update_record(subdomain, options)
      options.delete(:zone_root)
      options = @options.merge(options)
      options[:subdomain] = subdomain

      Chef::Log.info "Updating DNS record for #{name(options)}"

      # Try to get the record
      record = find_by_name_and_type(options)
      if record.nil?
        create_record(options)
      else
        if options[:value] and options[:value] != record.value
          Chef::Log.info "Destroying incorrect record (#{record.value.join ", "}) for #{name(options)}"
          record.destroy
          create_record(options)
        end
      end
    end

    # Delete a specified record
    def delete_record(subdomain, options)
      options = @options.merge(options)
      options[:subdomain] = subdomain
      record = find_by_name_and_type(options)
      if record
        Chef::Log.info "Deleting record for '#{record.name}'"
        record.destroy
      end
    end

    # Converge on a collection of specified DNS entries
    def create_or_update_deployment_records(definitions, env_name, attributes)
      definitions.each do |record_name, record|
        fail "A DNS record must have a value" unless record[:value]

        options = {}
        options[:value] = record[:value]
        options[:type] = record[:type]
        options[:prefix] = env_name if attributes[:use_subdomain]
        options[:ttl] = attributes["dns_ttl"]

        create_or_update_record(record_name, options)
      end
    end

    def delete_deployment_records(definitions, env_name, attributes)
      definitions.each do |record_name, record|
        options = {}
        options[:type] = record[:type]
        options[:prefix] = env_name if attributes[:use_subdomain]

        delete_record(record_name, options)
      end
    end

    def create_node_records(nodes)
      nodes.each do |n|
        subdomain, options = calculate_options_from_node(n)
        options[:value] = [ n[:cloud][:public_ipv4] ]
        create_or_update_record(subdomain, options)
      end
    end

    def delete_node_records(nodes)
      nodes.each do |n|
        subdomain, options = calculate_options_from_node(n)
        delete_record(subdomain, options)
      end
    end

    private

    def find_by_name_and_type(options)
      zone.records.all!.select do |r|
        r.name == name(options) and r.type.upcase == options[:type].upcase
      end.first
    end

    def calculate_options_from_node(node)
      options = {}
      subdomain = node.name.split("-")[1]
      subdomain << "-#{node[:clearwater][:index]}" if node[:clearwater][:index]
      options[:prefix] = node.environment if node[:clearwater][:use_subdomain]
      options[:type] = "A"
      [subdomain, options]
    end

    def dotted_join(*parts)
      parts.select {|a| not a.nil? and not a.empty?}.join(".")
    end

    def name(options)
      dotted_join(options[:subdomain], options[:prefix], options[:zone_root]) + "."
    end

    # Get DNS provider
    def dns
      @dns ||= Fog::DNS.new provider: "aws",
                            aws_access_key_id: Chef::Config[:knife][:aws_access_key_id],
                            aws_secret_access_key: Chef::Config[:knife][:aws_secret_access_key]
    end

    # Get zone (this is cached across the lifetime of the record manager)
    def zone
      @zone ||= dns.zones.all.select do |z|
        z.domain == @options[:zone_root] + "."
      end.first
      raise "Couldn't find named zone #{@options[:zone_root]}" unless @zone
      @zone
    end

    # Do the work
    def create_record(options)
      begin
        record_data = {
          name: name(options),
          type: options[:type],
          value: options[:value],
          ttl: options[:ttl],
        }

        Chef::Log.info "Creating record with config: #{record_data}"
        zone.records.create(record_data)

      rescue Excon::Errors::BadRequest => e
        msg = Nokogiri::XML(e.response.body).xpath("//xmlns:Message").text
        message = "Creation of #{name(options)} failed: #{msg}"
        Chef::Log.error(message)
        raise e
      end
    end
  end
end
