# @file bind-records.rb
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

require 'net/scp'
require 'net/ssh'

module Clearwater
  class BindRecordManager
    def initialize(domain, attributes)
      @domain = domain
      @ssh_key = "#{attributes["keypair_dir"]}/#{attributes["keypair"]}.pem"
    end

    # Converge on the specified zone record entry
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
