# @file knife-clearwater-utils.rb
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

module ClearwaterKnifePlugins
  module ClearwaterUtils
    # :nodoc:
    # Would prefer to do this in a rational way, but can't be done b/c of
    # Mixlib::CLI's design :(
    def self.included(includer)
      includer.class_eval do
        option :environment,
               :short => "-E ENVIRONMENT",
               :long => "--environment ENVIRONMENT",
               :required => "true",
               :description => "Clearwater environment to create new deployment in"
      end
    end

    def env
      begin
        @env ||= Chef::Environment.load(config[:environment])
      rescue
        puts "No such environment: #{config[:environment]}"
        exit 1
      end
    end

    # Load in clearwater attributes
    def attributes
      if @attributes
        @attributes
      else
        base_att = Chef::Role.load("clearwater-infrastructure").default_attributes["clearwater"]
        env_att = env.override_attributes["clearwater"]
        if env_att.nil?
          @attributes = base_att
        else
          @attributes = base_att.merge(env_att)
        end
      end
    end

    def find_nodes(options={})
      search(:node, query_string(true, options))
    end

    def find_clients(options={})
      search(:client, query_string(false, options))
    end

    def query_string(add_env, options={})
      options[:chef_environment] ||= env if add_env
      options.map do |k,v|
        "#{k}:#{v}"
      end.join(" AND ")
    end

    def search(*args)
      @query_tool ||= Chef::Search::Query.new
      @query_tool.search(*args).first.compact
    end

    def continue? (prompt = "Continue?")
      return true if config[:yes]
      loop do
        cont = (ui.ask "#{prompt} (y/N)").downcase
        return true if cont == "y"
        return false if cont == "n" or cont == ""
        ui.msg "I'm sorry, I couldn't understand your answer"
      end
    end

    # Expands out hashes of boxes, e.g. {:bono => 3} becomes:
    # {{:role => "bono", :index => 1}, {:role => "bono", :index = 2}, etc...
    def expand_hashes(boxes)
      boxes.map {|box, n| (1..n).map {|i| {:role => box.to_s, :index => i}}}.flatten
    end

    def node_name_from_definition(environment, role, index)
      "#{environment}-#{role}-#{index}"
    end
  end
end
