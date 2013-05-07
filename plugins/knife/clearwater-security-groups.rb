#!/usr/bin/env ruby

# @file clearwater-security-groups.rb
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

def base_security_group_rules
  [
    # ICMP ping
    { ip_protocol: :icmp, min: 0, max: -1, cidr_ip: "0.0.0.0/0" },
    { ip_protocol: :icmp, min: 8, max: -1, cidr_ip: "0.0.0.0/0" },
    # ICMP Destination Unreachable (required for PMTUD)
    { ip_protocol: :icmp, min: 3, max: -1, cidr_ip: "0.0.0.0/0" },
    # SSH
    { ip_protocol: :tcp, min: 22, max: 22, cidr_ip: "0.0.0.0/0" },
    # NTP
    { ip_protocol: :udp, min: 123, max: 123, cidr_ip: "0.0.0.0/0" },
    # Monit
    { ip_protocol: :tcp, min: 2812, max: 2812, group: "mmonit" },
    # SNMP from cacti
    { ip_protocol: :udp, min: 161, max: 162, group: "cacti" },
  ]
end

def ipsec_security_group_rules
  [
    # IKE/ISAKMP
    { ip_protocol: :udp, min: 500, max: 500, cidr_ip: "0.0.0.0/0" },
    # NATT IPSEC
    { ip_protocol: :udp, min: 4500, max: 4500, cidr_ip: "0.0.0.0/0" },
  ]
end

def bono_security_group_rules
  [
    # STUN
    { ip_protocol: :tcp, min: 3478, max: 3478, cidr_ip: "0.0.0.0/0" },
    { ip_protocol: :udp, min: 3478, max: 3478, cidr_ip: "0.0.0.0/0" },
    # External SIP (UDP and TCP)
    { ip_protocol: :tcp, min: 5060, max: 5060, cidr_ip: "0.0.0.0/0" },
    { ip_protocol: :udp, min: 5060, max: 5060, cidr_ip: "0.0.0.0/0" },
    # SIP/Websockets
    { ip_protocol: :tcp, min: 5062, max: 5062, cidr_ip: "0.0.0.0/0" },
    # Internal SIP (TCP only)
    { ip_protocol: :tcp, min: 5058, max: 5058, group: "bono" },
    { ip_protocol: :tcp, min: 5058, max: 5058, group: "sprout" },
    # Statistics interface
    { ip_protocol: :tcp, min: 6666, max: 6666, cidr_ip: "0.0.0.0/0" },
    # RTP
    { ip_protocol: :udp, min: 32768, max: 65535, cidr_ip: "0.0.0.0/0" },
  ]
end

def ibcf_security_group_rules
  []
end

def sprout_security_group_rules
  ipsec_security_group_rules +
    [
      # SIP from bono and Perimeta
      { ip_protocol: :tcp, min: 5058, max: 5058, group: "bono" },
      { ip_protocol: :tcp, min: 5058, max: 5058, group: "perimeta" },
      # Memcached from other sprout nodes
      { ip_protocol: :tcp, min: 11211, max: 11211, group: "sprout" },
      { ip_protocol: :udp, min: 11211, max: 11211, group: "sprout" },
      # Statistics interface
      { ip_protocol: :tcp, min: 6666, max: 6666, cidr_ip: "0.0.0.0/0" },
    ]
end

def homestead_security_group_rules
  ipsec_security_group_rules +
    [
      # API access from sprout/ellis, and restund on bono
      { ip_protocol: :tcp, min: 8888, max: 8888, group: "sprout" },
      { ip_protocol: :tcp, min: 8888, max: 8888, group: "bono" },
      { ip_protocol: :tcp, min: 8888, max: 8888, group: "ellis" },
      # Cassandra
      { ip_protocol: :tcp, min: 7000, max: 7000, group: "homestead" },
      { ip_protocol: :tcp, min: 9160, max: 9160, group: "homestead" },
    ]
end

def homer_security_group_rules
  ipsec_security_group_rules +
    [
      { ip_protocol: :tcp, min: 7888, max: 7888, group: "sprout" },
      { ip_protocol: :tcp, min: 7888, max: 7888, group: "ellis" },
      # Cassandra
      { ip_protocol: :tcp, min: 7000, max: 7000, group: "homer" },
      { ip_protocol: :tcp, min: 9160, max: 9160, group: "homer" },
    ]
end

def ellis_security_group_rules
  [
    # HTTP
    { ip_protocol: :tcp, min: 80, max: 80, cidr_ip: "0.0.0.0/0" },
    { ip_protocol: :tcp, min: 443, max: 443, cidr_ip: "0.0.0.0/0" },
  ]
end

def dns_security_group_rules
  [
    # DNS
    { ip_protocol: :tcp, min: 53, max: 53, cidr_ip: "0.0.0.0/0" },
    { ip_protocol: :udp, min: 53, max: 53, cidr_ip: "0.0.0.0/0" },
  ]
end

def enum_security_group_rules
  [
    # DNS
    { ip_protocol: :tcp, min: 53, max: 53, cidr_ip: "0.0.0.0/0" },
    { ip_protocol: :udp, min: 53, max: 53, cidr_ip: "0.0.0.0/0" },
  ]
end

def cacti_security_group_rules
  [
    # HTTP
    { ip_protocol: :tcp, min: 80, max: 80, cidr_ip: "0.0.0.0/0" },
  ]
end

def mmonit_security_group_rules
  [
    # HTTP
    { ip_protocol: :tcp, min: 80, max: 80, cidr_ip: "0.0.0.0/0" },
    { ip_protocol: :tcp, min: 443, max: 443, cidr_ip: "0.0.0.0/0" },
  ]
end

def perimeta_security_group_rules
  [
    # Global SIP
    { ip_protocol: :tcp, min: 5060, max: 5060, cidr_ip: "0.0.0.0/0" },
    # SIP from bono/sprout
    { ip_protocol: :tcp, min: 5058, max: 5058, group: "bono" },
    { ip_protocol: :tcp, min: 5058, max: 5058, group: "sprout" },
  ]
end

def repo_security_group_rules
  [
    # HTTP
    { ip_protocol: :tcp, min: 80, max: 80, group: "base" },
    # SSH
    { ip_protocol: :tcp, min: 22, max: 22, cidr_ip: "0.0.0.0/0" },
  ]
end

def clearwater_security_groups
  {
    "base" => base_security_group_rules,
    "repo" => repo_security_group_rules,
    "bono" => bono_security_group_rules,
    "ibcf" => ibcf_security_group_rules,
    "sprout" => sprout_security_group_rules,
    "homestead" => homestead_security_group_rules,
    "homer" => homer_security_group_rules,
    "ellis" => ellis_security_group_rules,
    "dns" => dns_security_group_rules,
    "enum" => enum_security_group_rules,
    "cacti" => cacti_security_group_rules,
    "mmonit" => mmonit_security_group_rules,
    "perimeta" => perimeta_security_group_rules,
  }
end
