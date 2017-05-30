# @file dns-records.rb
#
# Copyright (C) Metaswitch Networks 2017
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

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

      Chef::Log.info "Updating DNS record for #{name(options)} options = #{options}"

      # Try to get the record
      record = find_by_name_and_type(options)

      if options[:value] == []
        Chef::Log.info "Skipping empty record"
        return
      end
      if record.nil?
        create_record(options)
      else
        Chef::Log.debug "Found existing record, value = #{record.value}, ttl = #{record.ttl}"
        if (options[:value] and options[:value] != record.value) or
           (options[:ttl] and options[:ttl] != record.ttl)
          Chef::Log.info "Modify incorrect record (#{record.value.join ", "}) for #{name(options)}"
          modify_record(record, options)
        end
      end
    end

    # Converge on a collection of specified DNS entries
    def create_or_update_deployment_records(definitions, env_name, attributes)
      definitions.each do |record_name, record|
        fail "A DNS record must have a value" unless record[:value]

        options = {}
        options[:value] = record[:value]
        options[:type] = record[:type]
        options[:prefix] = env_name if attributes["use_subdomain"]
        options[:ttl] = record[:ttl] || attributes["dns_ttl"].to_s

        create_or_update_record(record_name, options)
      end
    end

    def delete_deployment_records(definitions, env_name, attributes)
      definitions.each do |record_name, record|
        options = {}
        options[:type] = record[:type]
        options[:prefix] = env_name if attributes["use_subdomain"]

        delete_record(record_name, options)
      end
    end

    def create_node_records(nodes, attributes)
      nodes.each do |n|
        subdomain, options = calculate_options_from_node(n)
        options[:value] = [ n[:cloud][:public_ipv4] ]
        options[:ttl] = attributes["dns_ttl"].to_s
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
      record = zone.records.get(name(options), options[:type])

      # Sleep to comply with Route53 rate-limit
      sleep(3)

      record
    end

    def calculate_options_from_node(node)
      options = {}
      subdomain = node.name.split("-")[1]
      subdomain << "-site#{node[:clearwater][:site]}" if node[:clearwater][:site] && node[:clearwater][:site] > 1
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

    def log_if_dns_error(options)
      begin
        yield
      rescue Excon::Errors::BadRequest => e
        msg = Nokogiri::XML(e.response.body).xpath("//xmlns:Message").text
        message = "Creation of DNS record failed: #{msg}"
        Chef::Log.error(message)
        raise e
      end
    end

    def make_record_data(options)
      {
        name: name(options),
        type: options[:type],
        value: options[:value],
        ttl: options[:ttl],
      }
    end

    # Create a new record
    def create_record(options)
      log_if_dns_error(options) do
        record_data = make_record_data(options)
        Chef::Log.info "Creating record with config: #{record_data}"
        zone.records.create(record_data)
      end

      # Sleep to comply with Route53 rate-limit
      sleep(1)
    end

    # Modify an existing record
    def modify_record(record, options)
      log_if_dns_error(options) do
        record_data = make_record_data(options)
        Chef::Log.info "Updating record with config: #{record_data}"
        record.modify(record_data)
      end

      # Sleep to comply with Route53 rate-limit
      sleep(3)
    end

    # Delete a specified record
    def delete_record(subdomain, options)
      options = @options.merge(options)
      options[:subdomain] = subdomain
      Chef::Log.info "delete_record with options #{options}"
      record = find_by_name_and_type(options)
      if record
        Chef::Log.info "Deleting record for '#{record.name}'"
        record.destroy
        Chef::Log.info "Deleted record for '#{record.name}'"

        # Sleep to comply with Route53 rate-limit
        sleep(3)
      end
    end
  end
end
