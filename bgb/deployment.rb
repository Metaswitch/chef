# @file deployment.rb
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
