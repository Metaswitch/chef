# @file dns-records.rb
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
    def create_or_update_deployment_records(definitions, env, attributes)
      definitions.each do |record_name, record|
        fail "A DNS record must have a value" unless record[:value]

        options = {}
        options[:value] = record[:value]
        options[:type] = record[:type]
        options[:prefix] = env.name if env.name != "_default"
        options[:ttl] = attributes["dns_ttl"]

        create_or_update_record(record_name, options)
      end
    end

    def delete_deployment_records(definitions, env)
      definitions.each do |record_name, record|
        options = {}
        options[:type] = record[:type]
        options[:prefix] = env.name if env.name != "_default"

        delete_record(record_name, options)
      end
    end

    def create_node_records(nodes, attributes)
      nodes.each do |n|
        subdomain, options = calculate_options_from_node(n)
        options[:value] = [ n[:cloud][:public_ipv4] ]
        options[:ttl] = attributes["dns_ttl"]
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
      options[:prefix] = node.environment unless node.environment == "_default"
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
