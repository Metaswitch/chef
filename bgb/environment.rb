# @file environment.rb
#
# Copyright (C) Metaswitch Networks 2013
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

require 'chef/knife'
require 'chef/knife/environment_from_file'
require 'erb'
Chef::Knife::EnvironmentFromFile.load_deps

# Load in the knife config file
Chef::Config.from_file(File.join(ENV['HOME'], ".chef", "knife.rb"))

class Environment
  attr_reader :environment

  def initialize(name, number_count=1000)
    b = binding
    @name = name
    @number_count = number_count
    puts "Creating environment #{name} with #{number_count} numbers..."
    env_template = ERB.new(File.read(File.join('environments', 'environment.erb')))
    File.open(File.join('environments', "#{name}.rb"), 'w') do |file|
      file.write(env_template.result(b))
    end
    env_create = Chef::Knife::EnvironmentFromFile.new
    env_create.name_args = [File.join('environments', "#{name}.rb")]
    env_create.run
  end
end
