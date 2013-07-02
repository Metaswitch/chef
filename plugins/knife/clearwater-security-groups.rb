#!/usr/bin/env ruby

# @file clearwater-security-groups.rb
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
    # DEPRECTATED: Internal SIP (TCP only) - these should be removed once all
    # deployments are migrated to using internal-sip security groups.
    { ip_protocol: :tcp, min: 5058, max: 5058, group: "bono" },
    { ip_protocol: :tcp, min: 5058, max: 5058, group: "sprout" },
    { ip_protocol: :tcp, min: 5058, max: 5058, group: "internal-sip" },
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
      # DEPRECTATED: Internal SIP (TCP only) - these should be removed once all
      # deployments are migrated to using internal-sip security groups.
      { ip_protocol: :tcp, min: 5058, max: 5058, group: "bono" },
      { ip_protocol: :tcp, min: 5058, max: 5058, group: "perimeta" },
      { ip_protocol: :tcp, min: 5058, max: 5058, group: "internal-sip" },
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
    # DEPRECTATED: Internal SIP (TCP only) - these should be removed once all
    # deployments are migrated to using internal-sip security groups.
    { ip_protocol: :tcp, min: 5058, max: 5058, group: "bono" },
    { ip_protocol: :tcp, min: 5058, max: 5058, group: "sprout" },
    { ip_protocol: :tcp, min: 5058, max: 5058, group: "internal-sip" },
  ]
end

def repo_security_group_rules
  [
    # HTTP
    { ip_protocol: :tcp, min: 80, max: 80, cidr_ip: "0.0.0.0/0" },
    # SSH
    { ip_protocol: :tcp, min: 22, max: 22, cidr_ip: "0.0.0.0/0" },
  ]
end

# The internal-sip security group should be used for any nodes that need to
# communicate internally via SIP.  bono, sprout, perimeta and any application
# servers should all be members of this group, and this would avoid having to
# touch bono, sprout and perimeta's security groups every time we add another
# node type.  Unfortunately, it's hard to add new security groups to existing
# nodes, so for now this security group must also contain explicit rules for
# bono, sprout and perimeta.  Hopefully at some stage we'll be able to retire
# these legacy rules.
def internal_sip_security_group_rules
  [
    # Internal SIP (TCP only)
    { ip_protocol: :tcp, min: 5058, max: 5058, group: "internal-sip" },
    # Internal SIP (TCP only) - legacy rules
    { ip_protocol: :tcp, min: 5058, max: 5058, group: "bono" },
    { ip_protocol: :tcp, min: 5058, max: 5058, group: "sprout" },
    { ip_protocol: :tcp, min: 5058, max: 5058, group: "perimeta" },
  ]
end

def plivo_security_group_rules
  [
    # RTP - bono does not proxy the media stream to application servers
    { ip_protocol: :udp, min: 32768, max: 65535, cidr_ip: "0.0.0.0/0" },
  ]
end

def sipp_security_group_rules
  [
    # External SIP (UDP and TCP)
    { ip_protocol: :tcp, min: 5060, max: 5060, cidr_ip: "0.0.0.0/0" },
    { ip_protocol: :udp, min: 5060, max: 5060, cidr_ip: "0.0.0.0/0" },
    # Statistics interface
    { ip_protocol: :tcp, min: 6666, max: 6666, cidr_ip: "0.0.0.0/0" },
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
    "internal-sip" => internal_sip_security_group_rules,
    "plivo" => plivo_security_group_rules,
    "sipp" => sipp_security_group_rules,
  }
end
