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
    # Options may optionally be specified at create time and overwritten for each record created.
    def initialize(domain)
      @options = {}
      @options[:domain] = domain
    end

    # Converge on the specified zone record entry
    def create_or_update_records(dns_records, nodes)
      puts @zone_template
      ssh_options = { keys: ["/home/felix/.ssh/dogfood-cw-keypair.pem"] }
      Net::SSH.start(bind_server_ip, "ubuntu", ssh_options) do |ssh|
        create_or_update_conf_files(ssh)
        create_or_update_zone_descriptions(ssh, dns_records, nodes)
        Chef::Log.info "Reloading rndc on BIND server"
        ssh.exec "sudo rndc reload"
      end
    end

    def create_or_update_conf_files(ssh)
      ["internal", "external"].each do |location|
        zone_data = ssh.scp.download!  "/etc/bind/named.conf.#{location}-zones"
        definition = zone_definition location
        regex = Regexp.new definition
        if regex.match zone_data
          Chef::Log.info "#{location.capitalize} DNS zone for #{@options[:domain]} already exists"
        else
          Chef::Log.info "Creating #{location} DNS zone for #{@options[:domain]}"
          zone_data += definition
          # scp cannot copy directly to /etc/bind, so use a temp file
          ssh.scp.upload! StringIO.new(zone_data), "tmp_#{location}"
          ssh.exec "sudo mv tmp_#{location} /etc/bind/named.conf.#{location}-zones"
        end
      end
    end

    def create_or_update_zone_descriptions(ssh, dns_records, nodes)
      ["internal", "external"].each do |location|
        Chef::Log.info "Updating #{location} DNS zone file for #{@options[:domain]}"
        template_file = "#{File.dirname(__FILE__)}/templates/bind/#{location}.erb"
        template = ERB.new File.read(template_file)
        zone_file_data = template.result(binding)
        # scp cannot copy directly to /var/cache/bind/zones so use a temp file
        ssh.scp.upload! StringIO.new(zone_file_data), "tmp_#{location}"
        ssh.exec "sudo mv tmp_#{location} /var/cache/bind/zones/#{location}.#{@options[:domain]}"
      end
    end

    def bind_server_ip
      @bind_server_ip ||= Chef::Config[:knife][:bind_server_ip]
      raise "Couldn't load BIND server IP, please configure knife[:bind_server_ip]" unless @bind_server_ip
      @bind_server_ip
    end

    def bind_server_contact
      @bind_server_contact ||= Chef::Config[:knife][:bind_server_contact]
      raise "Couldn't load BIND server contact, please configure knife[:bind_server_contact]" unless @bind_server_contact
      @bind_server_contact
    end

    def zone_definition(location)
# ERB?
      "zone \"#{@options[:domain]}\" IN \{ type master; file \"zones\/#{location}\.#{@options[:domain]}\"; \};\n"
    end
  end
end
