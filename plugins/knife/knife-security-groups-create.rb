# @file knife-security-groups-create.rb
#
# Copyright (C) Metaswitch Networks 2015
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

require_relative 'knife-clearwater-utils'
require_relative 'security-groups'
require_relative 'clearwater-security-groups'

module ClearwaterKnifePlugins
  class SecurityGroupsCreate < Chef::Knife
    include Clearwater::SecurityGroups
    include ClearwaterKnifePlugins::ClearwaterUtils

    banner "knife security groups create"

    deps do
      require 'chef'
      require 'fog'
      require 'nokogiri'
    end

    def run
      extra_internal_sip_groups = attributes["extra_internal_sip_groups"] || {}
      groups = clearwater_security_groups(extra_internal_sip_groups)
      commission_security_groups(groups,
                                 env,
                                 attributes["region"])
    end
  end
end
