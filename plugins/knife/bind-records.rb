# @file bind-records.rb
#
# Copyright (C) Metaswitch Networks 2013
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

require 'net/scp'
require 'net/ssh'

module Clearwater
  class BindRecordManager
    # Initializer
    #
    # @param domain [String] root domain to create records in
    # @param attributes [Hash{String => String}] Chef attributes, used for
    #   accessing the configured ssh keypair
    def initialize(domain, attributes)
      @domain = domain
      @ssh_key = File.join(attributes["keypair_dir"], "#{attributes["keypair"]}.pem")
    end

    # Configures a BIND server with the specified records and creates
    # individual records for nodes
    #
    # @param dns_records [Hash{String => String, Array<String>}] the DNS records.
    #   See clearwater-dns-records.rb for details
    # @param nodes [Array<Node>] an array of Chef nodes to create BIND entries for
    def create_or_update_records(dns_records, nodes)
      # First create config in BIND server
      ssh_options = { keys: @ssh_key }
      Net::SSH.start(bind_server_private_ip, "ubuntu", ssh_options) do |ssh|
        create_or_update_zone_root_files(ssh)
        create_or_update_zone_description_files(ssh, dns_records, nodes)
        Chef::Log.info "Reloading rndc on BIND server"
        ssh.exec "sudo rndc reload"
      end

      # Configure nodes to point at BIND server
      nodes.each { |node| point_node_at_bind_server node }
    end

    private
    def create_or_update_zone_root_files(ssh)
      ["internal", "external"].each do |location|
        zone_data = ssh.scp.download!  "/etc/bind/named.conf.#{location}-zones"
        definition = zone_definition location
        regex = Regexp.new definition
        if regex.match zone_data
          Chef::Log.info "#{location.capitalize} DNS zone for #{@domain} already exists"
        else
          Chef::Log.info "Creating #{location} DNS zone for #{@domain}"
          zone_data += definition
          upload_to_file ssh, zone_data, "/etc/bind/named.conf.#{location}-zones"
        end
      end
    end

    def create_or_update_zone_description_files(ssh, dns_records, nodes)
      ["internal", "external"].each do |location|
        Chef::Log.info "Updating #{location} DNS zone file for #{@domain}"
        template_file = "#{File.dirname(__FILE__)}/templates/bind/#{location}.erb"
        template = ERB.new File.read(template_file)
        zone_file_data = template.result(binding)
        upload_to_file ssh, zone_file_data, "/var/cache/bind/zones/#{location}.#{@domain}"
      end
    end

    def point_node_at_bind_server(node)
      ssh_options = { keys: @ssh_key }
      Net::SSH.start(node[:cloud][:local_ipv4], "ubuntu", ssh_options) do |ssh|
        Chef::Log.info "Pointing #{node.name} at BIND server..."
        dhcp_conf = ssh.scp.download! "/etc/dhcp/dhclient.conf"
        supersede_line = "\nsupersede domain-name-servers #{bind_server_private_ip};"
        regex = Regexp.new supersede_line
        if regex.match dhcp_conf
          Chef::Log.info "DHCP already configured to point at BIND server"
        else
          Chef::Log.info "Configuring DHCP to point at BIND server"
          dhcp_conf += supersede_line
          upload_to_file ssh, dhcp_conf, "/etc/dhcp/dhclient.conf"
          Chef::Log.info "Rebooting..."
          ssh.exec! "sudo reboot"
        end
      end
    end

    def upload_to_file(ssh, data, remote_file)
      # scp cannot copy directly to protected locations so use a temp file
      ssh.scp.upload! StringIO.new(data), "tmp"
      ssh.exec! "sudo mv tmp #{remote_file}"
      ssh.exec! "sudo chown root:bind #{remote_file}"
      ssh.exec! "sudo chmod 644 #{remote_file}"
    end

    def bind_server_public_ip
      @bind_server_public_ip ||= Chef::Config[:knife][:bind_server_public_ip]
      raise "Couldn't load BIND server IP, please configure knife[:bind_server_public_ip]" unless @bind_server_public_ip
      @bind_server_public_ip
    end

    def bind_server_private_ip
      @bind_server_private_ip ||= Chef::Config[:knife][:bind_server_private_ip]
      raise "Couldn't load BIND server IP, please configure knife[:bind_server_private_ip]" unless @bind_server_private_ip
      @bind_server_private_ip
    end

    def bind_server_contact
      @bind_server_contact ||= Chef::Config[:knife][:bind_server_contact]
      raise "Couldn't load BIND server contact, please configure knife[:bind_server_contact]" unless @bind_server_contact
      @bind_server_contact
    end

    def zone_definition(location)
      "zone \"#{@domain}\" IN { type master; file \"zones/#{location}.#{@domain}\"; };\n"
    end
  end
end
