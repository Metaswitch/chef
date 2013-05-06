#!/usr/bin/env ruby

# @file clearwater-dns-records.rb
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

def dns_records
  {
    "" => {
      :type  => "A",
      :value => ipv4s(find_nodes(role: "bono")),
    },

    "sprout" => {
      :type  => "A",
      :value => ipv4s_local(find_nodes(role: "sprout")),
    },

    "hs" => {
      :type  => "A",
      :value => ipv4s_local(find_nodes(role: "homestead")),
    },

    "homer" => {
      :type => "A",
      :value => ipv4s_local(find_nodes(role: "homer")),
    },

    "ellis" => {
      :type => "A",
      :value => ipv4s(find_nodes(role: "ellis")),
    },

    # "splunk" => {
    #   :type => "CNAME",
    #   :value => public_hostnames(find_nodes(role: "splunk")),
    # },
    #
    # "mmonit" => {
    #   :type => "CNAME",
    #   :value => public_hostnames(find_nodes(role: "mmonit")),
    # },
  }
end

def ipv4s(boxes)
  boxes.map {|n| n[:cloud][:public_ipv4]}
end

def ipv4s_local(boxes)
  boxes.map {|n| n[:cloud][:local_ipv4]}
end

def public_hostnames(boxes)
  boxes.map {|n| n[:cloud][:public_hostname] + "."}
end
