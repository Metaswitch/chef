# @file environment.rb
#
# Copyright (C) 2013  Metaswitch Networks Ltd
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# The author can be reached by email at clearwater@metaswitch.com or by post at
# Metaswitch Networks Ltd, 100 Church St, Enfield EN2 6BQ, UK

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
