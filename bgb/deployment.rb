# @file deployment.rb
#
# Copyright (C) Metaswitch Networks 2013
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

require 'chef/knife'
require 'timeout'
require_relative '../plugins/knife/knife-clearwater-utils'
require_relative '../plugins/knife/knife-deployment-resize'
ClearwaterKnifePlugins::DeploymentResize.load_deps

# Load in the knife config file
Chef::Config.from_file(File.join(ENV['HOME'], ".chef", "knife.rb"))

class Deployment
  attr_reader :environment

  @@deployments = {}
  def self.all
    @@deployments
  end

  def self.get(environment)
    @@deployments[environment]
  end

  def initialize(environment)
    @@deployments[environment] = self
    @environment = environment
    puts "Creating thread for deployment..."
    @knife_thread = Thread.new do
      puts "Creating deployment #{environment}"
      begin
        deployment_create = ClearwaterKnifePlugins::DeploymentResize.new("-E #{environment}".split)
        deployment_create.merge_configs
        deployment_create.config[:yes] = true
        deployment_create.config[:verbosity] = :info
        Chef::Config[:verbosity] = :info
        # Chef doesn't pick up on the environment passed in above, so manually configure
        Chef::Config[:environment] = environment
        Timeout::timeout(3600) do
          deployment_create.run
        end
      rescue Exception => e
        puts "Knife deployment for environment #{@environment} hit error:"
        puts "#{e.class}: #{e.message}"
        puts e.backtrace.join("  \n")
      end
    end
  end

  def to_json(options={})
    {
      :id => @environment, 
      :environment => @environment, 
      :status => @knife_thread[:status],
      :progress => @knife_thread[:progress]
    }.to_json
  end
end
