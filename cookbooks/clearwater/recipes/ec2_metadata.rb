# @file ec2_metadata.rb
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

#
# Author:: Tim Dysinger (<tim@dysinger.net>)
# Author:: Benjamin Black (<bb@opscode.com>)
# Author:: Christopher Brown (<cb@opscode.com>)
# Copyright:: Copyright (c) 2009 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'net/http'
require 'socket'

module Ohai
  module Mixin
    ##
    # This code parses the EC2 Instance Metadata API to provide details
    # of the running instance.
    #
    # Earlier version of this code assumed a specific version of the
    # metadata API was available. Unfortunately the API versions
    # supported by a particular instance are determined at instance
    # launch and are not extended over the life of the instance. As such
    # the earlier code would fail depending on the age of the instance.
    #
    # The updated code probes the instance metadata endpoint for
    # available versions, determines the most advanced version known to
    # work and executes the metadata retrieval using that version.
    #
    # If no compatible version is found, an empty hash is returned.
    #
    class Ec2Metadata

      EC2_METADATA_ADDR = "169.254.169.254" unless defined?(EC2_METADATA_ADDR)
      EC2_SUPPORTED_VERSIONS = %w[ 1.0 2007-01-19 2007-03-01 2007-08-29 2007-10-10 2007-12-15
                                   2008-02-01 2008-09-01 2009-04-04 2011-01-01 2011-05-01 2012-01-12 ]

      EC2_ARRAY_VALUES = %w(security-groups)
      EC2_ARRAY_DIR    = %w(network/interfaces/macs)
      EC2_JSON_DIR     = %w(iam)

      def can_metadata_connect?(addr, port, timeout=2)
        t = Socket.new(Socket::Constants::AF_INET, Socket::Constants::SOCK_STREAM, 0)
        saddr = Socket.pack_sockaddr_in(port, addr)
        connected = false

        begin
          t.connect_nonblock(saddr)
        rescue Errno::EINPROGRESS
          r,w,e = IO::select(nil,[t],nil,timeout)
          if !w.nil?
            connected = true
          else
            begin
              t.connect_nonblock(saddr)
            rescue Errno::EISCONN
              t.close
              connected = true
            rescue SystemCallError
            end
          end
        rescue SystemCallError
        end
        connected
      end

      def best_api_version
        response = http_client.get("/")
        unless response.code == '200'
          raise "Unable to determine EC2 metadata version (returned #{response.code} response)"
        end
        # Note: Sorting the list of versions may have unintended consequences in
        # non-EC2 environments. It appears to be safe in EC2 as of 2013-04-12.
        versions = response.body.split("\n")
        versions = response.body.split("\n").sort
        until (versions.empty? || EC2_SUPPORTED_VERSIONS.include?(versions.last)) do
          pv = versions.pop
        end
        if versions.empty?
          raise "Unable to determine EC2 metadata version (no supported entries found)"
        end
        versions.last
      end

      def http_client
        Net::HTTP.start(EC2_METADATA_ADDR).tap {|h| h.read_timeout = 600}
      end

      def metadata_get(id, api_version)
        response = http_client.get("/#{api_version}/meta-data/#{id}")
        unless response.code == '200'
          raise "Encountered error retrieving EC2 metadata (returned #{response.code} response)"
        end
        response
      end

      def fetch_metadata(id='', api_version=nil)
        api_version ||= best_api_version
        return Hash.new if api_version.nil?
        metadata = Hash.new
        metadata_get(id, api_version).body.split("\n").each do |o|
          key = expand_path("#{id}#{o}")
          if key[-1..-1] != '/'
            metadata[metadata_key(key)] =
              if EC2_ARRAY_VALUES.include? key
                metadata_get(key, api_version).body.split("\n")
              else
                metadata_get(key, api_version).body
              end
          elsif not key.eql?(id) and not key.eql?('/')
            name = key[0..-2]
            sym = metadata_key(name)
            if EC2_ARRAY_DIR.include?(name)
              metadata[sym] = fetch_dir_metadata(key, api_version)
            elsif EC2_JSON_DIR.include?(name)
              metadata[sym] = fetch_json_dir_metadata(key, api_version)
            else
              fetch_metadata(key, api_version).each{|k,v| metadata[k] = v}
            end
          end
        end
        metadata
      end

      def fetch_dir_metadata(id, api_version)
        metadata = Hash.new
          metadata_get(id, api_version).body.split("\n").each do |o|
          key = expand_path(o)
          if key[-1..-1] != '/'
            metadata[metadata_key(key)] = metadata_get("#{id}#{key}", api_version).body
          elsif not key.eql?('/')
            metadata[key[0..-2]] = fetch_dir_metadata("#{id}#{key}", api_version)
          end
        end
        metadata
      end

      def fetch_json_dir_metadata(id, api_version)
        metadata = Hash.new
        metadata_get(id, api_version).body.split("\n").each do |o|
          key = expand_path(o)
          if key[-1..-1] != '/'
            data = metadata_get("#{id}#{key}", api_version).body
            json = StringIO.new(data)
            parser = Yajl::Parser.new
            metadata[metadata_key(key)] = parser.parse(json)
          elsif not key.eql?('/')
            metadata[key[0..-2]] = fetch_json_dir_metadata("#{id}#{key}", api_version)
          end
        end
        metadata
      end

      def fetch_userdata()
        api_version = best_api_version
        return nil if api_version.nil?
        response = http_client.get("/#{api_version}/user-data/")
        response.code == "200" ? response.body : nil
      end

      private

      def expand_path(file_name)
        path = file_name.gsub(/\=.*$/, '/')
        # ignore "./" and "../"
        path.gsub(%r{/\.\.?(?:/|$)}, '/').
          sub(%r{^\.\.?(?:/|$)}, '').
          sub(%r{^$}, '/')
      end

      def metadata_key(key)
        key.gsub(/\-|\//, '_')
      end

    end
  end
end

# TODO - Remove this file once ohai is updated beyond version 6.16.0
# We need to do this as openstack doesn't correctly populate the :cloud hash
# on older systems
patch_up = ruby_block "patch_up_metadata" do
  block do
    meta = Ohai::Mixin::Ec2Metadata.new
    if meta.can_metadata_connect?("169.254.169.254", 80)
      metadata = meta.fetch_metadata
      keys = node[:cloud].keys
      keys.each { |k| node.automatic[:cloud][k] = metadata[k] unless metadata[k].nil? }
      node.save
    end

    # Patch up openstack systems
    unless node[:openstack].nil?
      env = node.name.split("-").first
      dns_name = node.name.split("#{env}-").last
      node.automatic[:cloud][:provider] = "openstack" unless node[:cloud][:provider]
      node.automatic[:cloud][:public_hostname] = "#{dns_name}.#{env}.cw-ngv.com" # Always wrong
      if node[:openstack_patch]
        node.automatic[:openstack][:instance_id] = node[:openstack_patch][:instance_id] unless node[:openstack][:instance_id]
      end
      node.save
    end
  end
  action :nothing
end

unless Chef::Config[:solo]
  patch_up.run_action(:create)
end
