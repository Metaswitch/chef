# @file knife-security-groups-delete.rb
#
# Copyright (C) Metaswitch Networks
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

require_relative 'knife-clearwater-utils'
require_relative 'security-groups'
require_relative 'clearwater-security-groups'

module ClearwaterKnifePlugins
  class SecurityGroupsDelete < Chef::Knife
    include Clearwater::SecurityGroups
    include ClearwaterKnifePlugins::ClearwaterUtils

    banner "knife security groups delete"

    deps do
      require 'chef'
      require 'fog'
      require 'nokogiri'
    end

    def run
      extra_internal_sip_groups = attributes["extra_internal_sip_groups"] || {}
      groups = clearwater_security_groups(extra_internal_sip_groups)

      historical_groups = ["database"]
      historical_groups.each do |g|
        # We don't need to specify any rules - this entry just makes sure we
        # delete the group
        groups[g] = []
      end

      delete_security_groups(groups,
                             env,
                             attributes["region"])
    end
  end
end
