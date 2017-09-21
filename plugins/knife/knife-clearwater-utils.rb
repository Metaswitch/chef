# @file knife-clearwater-utils.rb
#
# Copyright (C) Metaswitch Networks 2016
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

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
        base_att = Chef::Role.load("chef-base").default_attributes["clearwater"]
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

    # Expands out hashes of boxes, e.g. {:bono-site1 => 3} becomes:
    # {{:role => "bono", :site => 1, :index => 1},
    # {:role => "bono", :site => 1, :index = 2}, etc...
    def expand_hashes(boxes)
      boxes.map {|box, n| (1..n).map {|i| expand_hash(box, i)}}.flatten
    end

    # Helper for the previous function. Checks that the passed hash has the
    # correct form.
    def expand_hash(box, index)
      box_split = box.to_s.split("-site")
      raise ArgumentError, "box hash must be of the form \"<role>-site<site number>\".
        \"#{box.to_s}\" was passed." unless box_split.length > 1
      return {:role=>box_split[0].to_s, :site=>box_split[1].to_i, :index=>index}
    end

    def node_name_from_definition(environment, role, site, index)
      if site == 1
        "#{environment}-#{role}-#{index}"
      else
        "#{environment}-#{role}-site#{site}-#{index}"
      end
    end
  end
end
