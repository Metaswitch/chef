# @file trigger-chef-client.rb
#
# Project Clearwater - IMS in the Cloud
# Copyright (C) 2015 Metaswitch Networks Ltd
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

module ClearwaterKnifePlugins
  module TriggerChefClient
    # Run the specified command on all nodes in the local environment that match
    # the given `query_string`.  This should only be used for "trigger" operations,
    # not for changing configuration - trigger_chef_client should be used for that.
    #
    # @param cloud [Symbol] The cloud hosting the devices.
    # @param query_string [String] A Chef-format query string to match on.
    # @param command [String] A shell command to run
    def run_command(cloud, query_string, command)
      Chef::Log.info "Running #{command} on #{query_string}"
      Chef::Knife::Ssh.load_deps
      knife_ssh = Chef::Knife::Ssh.new
      knife_ssh.merge_configs
      knife_ssh.config[:ssh_user] = 'ubuntu'
      knife_ssh.config[:attribute] = 'cloud.public_ipv4'
      if cloud == :openstack
        # Guard against boxes which do not have a public hostname
        knife_ssh.config[:attribute] = 'ipaddress'
      end
      knife_ssh.config[:identity_file] = "#{attributes["keypair_dir"]}/#{attributes["keypair"]}.pem"
      knife_ssh.config[:verbosity] = config[:verbosity]
      Chef::Config[:verbosity] = config[:verbosity]
      knife_ssh.config[:on_error] = :raise
      knife_ssh.name_args = [
        query_string,
        command
      ]
      knife_ssh.run
    end

    # Trigger `chef-client` on all nodes in the local environment that match
    # the given `query_string`.
    #
    # @param cloud [Symbol] The cloud hosting the devices.
    # @param query_string [String] A Chef-format query string to match on.
    def trigger_chef_client(cloud, query_string, restart_all=false)
      command = if restart_all
                  "sudo nice -n 19 chef-client; sudo monit restart all"
                else
                  "sudo nice -n 19 chef-client"
                end

      run_command(cloud, query_string, command)
    end
  end
end
