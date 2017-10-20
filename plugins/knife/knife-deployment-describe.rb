# @file knife-deployment-describe.rb
#
# Copyright (C) Metaswitch Networks 2016
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

require 'net/ssh'
require 'net/http'
require_relative 'knife-clearwater-utils'

module ClearwaterKnifePlugins
  class DeploymentDescribe < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils

    banner "knife deployment describe -E ENV"

    deps do
      require 'chef'
      require 'fog'
      require 'nokogiri'
    end

    option :repos,
      :long => "--repos REPO_SERVERS",
      :description => "Comma separated list of repo servers to compare to, e.g. http://abc.com,http://dfw.com"

    def run
      @ssh_key = File.join(attributes["keypair_dir"], "#{attributes["keypair"]}.pem")
      if config[:repos].nil?
        puts "No repo servers specified, just listing installed packages"
        versions = []
      else
        repos = config[:repos].split ","
        versions = repos.map { |r| fetch_package_versions r }
        repos.each_with_index { |repo, i| puts RedGreen::Color.color(i, repo) }
      end
      nodes = find_nodes.select { |n| n.roles.include? "chef-base" }
      nodes.sort_by(&:name).each { |n| describe_node n, versions }
    end

    private

    def describe_node(node, versions)
      hostname = node[:cloud][:public_hostname]
      puts "Packages on #{node.name}:"
      ssh_options = { keys: @ssh_key }
      begin
        Net::SSH.start(hostname, "ubuntu", ssh_options) do |ssh|
          node.roles.each do |role|
            if package_lookup.keys.include? role
              package_lookup[role].each do |package_name|
                raw_dkpg_output = ssh.exec! "dpkg -l #{package_name}"
                match_data = /#{package_name}\s+([0-9\.-]+)/.match raw_dkpg_output
                if match_data.nil?
                  puts "No package version found"
                else
                  version = match_data[1]
                  versions.each_with_index do |v, i|
                    if v[package_name] == version
                      version = RedGreen::Color.color(i, version)
                    end
                  end
                  format_str = "%-30s " + ("%s " * (1 + versions.length))
                  colored_versions = versions.each_with_index.map { |v, i| RedGreen::Color.color(i, v[package_name]) }
                  puts format_str % ([package_name, version] + colored_versions)
                end
              end
            end
          end
        end
      rescue Errno::EHOSTUNREACH
        Chef::Log.error "#{node.name} is unreachable"
      end
      puts "\n"
    end

    def package_lookup
      {
        "bono" => ["bono", "restund", "sprout-libs"],
        "ellis" => ["ellis"],
        "homer" => ["homer"],
        "ralf" => ["ralf", "chronos", "astaire"],
        "homestead" => ["homestead"],
        "sprout" => ["sprout", "sprout-libs", "memento"],
        "dime" => ["ralf", "homestead"],
        "vellum" => ["chronos", "astaire", "rogers"]
      }
    end

    def fetch_package_versions(server)
      uri = URI(server + '/binary/Packages')
      req = Net::HTTP::Get.new(uri.path)

      http_opts = {}
      if uri.scheme == "https"
        # Get the client-side keys from the databag and use them
        keys = Chef::EncryptedDataBagItem.load("repo_keys", "generic")
        raw_crt = keys["repository-server.crt"]
        raw_key = keys["repository-server.key"]
        http_opts = {:use_ssl => true,
                     :verify_mode => OpenSSL::SSL::VERIFY_NONE,
                     :cert => OpenSSL::X509::Certificate.new(raw_crt),
                     :key => OpenSSL::PKey::RSA.new(raw_key)}
      end

      package_info = Net::HTTP.start(uri.host, uri.port, http_opts) do |http|
        http.request(req)
      end

      package_list = package_info.body.split /\n\n/
      versions = {}
      package_list.each do |package|
        name = /Package: (.+)\n/.match package
        version = /Version: (.+)\n/.match package
        unless name.nil? or version.nil?
          versions[name[1]] = version[1]
        end
      end
      versions
    end
  end
end

# Source: RedGreen gem - https://github.com/kule/redgreen
module RedGreen
  module Color
    # green, yellow, red
    FG_COLORS = [ 30, 30, 37]
    BG_COLORS = [ 42, 43, 41 ]
    def self.color(color, text)
      if ENV['TERM']
        "\e[#{FG_COLORS[color]};#{BG_COLORS[color]}m#{text}\e[37;0m"
      else
        ""
      end
    end
  end
end
