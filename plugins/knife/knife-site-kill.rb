# @file knife-site-kill.rb
#
# Copyright (C) Metaswitch Networks 2016
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

require_relative 'knife-clearwater-utils'
require_relative 'trigger-chef-client'

module ClearwaterKnifePlugins
  class SiteKill < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils
    include ClearwaterKnifePlugins::TriggerChefClient

    banner "knife site kill -E ENV --site SITE"

    option :site,
      :long => "--site <site to kill>",
      :description => "Kills the site specified, except for the Bono nodes",
      :proc => Proc.new { |arg| Integer(arg) rescue begin Chef::Log.error "--site must be an integer"; exit 2 end }

    option :cloud,
      :long => "--cloud CLOUD",
      :default => "ec2",
      :description => "Cloud to create box in. Currently support: #{Clearwater::BoxManager.supported_clouds.join ', '}",
      :proc => (Proc.new do |arg|
        unless Clearwater::BoxManager.supported_clouds.include? arg.to_sym
          Chef::Log.error "#{arg} is not a supported cloud"
          exit 2
        end
      end)

    def run
      Chef::Log.info "Killing site #{config[:site]} in environment: #{config[:environment]}"

      # Find nodes in the specified site, excluding bono's
      nodes = find_nodes(roles: "chef-base", site: config[:site])
      nodes.select! { |n| not n.roles.include?("bono") }

      query_string_nodes = nodes.map { |n| "name:#{n.name}" }.join " OR "
      query_string = "chef_environment:#{config[:environment]} AND (#{query_string_nodes})"

      command = "sudo monit stop all"

      run_command(config[:cloud], query_string, command)
    end
  end
end
