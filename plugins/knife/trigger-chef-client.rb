# @file trigger-chef-client.rb
#
# Copyright (C) Metaswitch Networks 2016
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

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

      # Always SSH in over the public IP address
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

      # Run apt-get update first to make sure we have the latest packages.
      run_command(cloud, query_string, "sudo apt-get update")
      run_command(cloud, query_string, command)
    end
  end
end
