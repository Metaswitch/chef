# @file knife-site-recover.rb
#
# Copyright (C) Metaswitch Networks 2016
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

require_relative 'knife-deployment-utils'
require_relative 'knife-clearwater-utils'
require_relative 'trigger-chef-client'

module ClearwaterKnifePlugins
  class SiteRecover < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils
    include ClearwaterKnifePlugins::TriggerChefClient

    banner "knife site recover -E ENV --site SITE"

    option :site,
      :long => "--site <site to recover>",
      :description => "Recovers the spcified site",
      :proc => Proc.new { |arg| Integer(arg) rescue begin Chef::Log.error "--site must be an integer"; exit 2 end }

    def run
      Chef::Log.info "Recovering site #{config[:site]} in environment: #{config[:environment]}"

      # Find nodes in the specified site
      nodes = find_nodes(roles: "chef-base", site: config[:site])

      query_string_nodes = nodes.map { |n| "name:#{n.name}" }.join " OR "
      query_string = "chef_environment:#{config[:environment]} AND (#{query_string_nodes})"

      command = "sudo monit start all"

      run_command(config[:cloud], query_string, command)
    end
  end
end
