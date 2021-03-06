#!/usr/bin/env ruby

# @file clearwater-security-groups.rb
#
# Copyright (C) Metaswitch Networks 2017
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

def base_security_group_rules
  [
    # ICMP ping
    { ip_protocol: :icmp, min: 0, max: -1, cidr_ip: "0.0.0.0/0" },
    { ip_protocol: :icmp, min: 8, max: -1, cidr_ip: "0.0.0.0/0" },
    # ICMP Destination Unreachable (required for PMTUD)
    { ip_protocol: :icmp, min: 3, max: -1, cidr_ip: "0.0.0.0/0" },
    # SSH
    { ip_protocol: :tcp, min: 22, max: 22, cidr_ip: "0.0.0.0/0" },
    # SNMP
    { ip_protocol: :udp, min: 161, max: 161, cidr_ip: "0.0.0.0/0" },
    # Monit
    { ip_protocol: :tcp, min: 2812, max: 2812, group: "mmonit" },
    # etcd
    { ip_protocol: :tcp, min: 2380, max: 2380, group: "base" },
    { ip_protocol: :tcp, min: 4000, max: 4000, group: "base" },
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

def bono_external_security_group_rules
  [
    # STUN
    { ip_protocol: :tcp, min: 3478, max: 3478, cidr_ip: "0.0.0.0/0" },
    { ip_protocol: :udp, min: 3478, max: 3478, cidr_ip: "0.0.0.0/0" },
    # External SIP (UDP and TCP)
    { ip_protocol: :tcp, min: 5060, max: 5060, cidr_ip: "0.0.0.0/0" },
    { ip_protocol: :udp, min: 5060, max: 5060, cidr_ip: "0.0.0.0/0" },
    # SIP/Websockets
    { ip_protocol: :tcp, min: 5062, max: 5062, cidr_ip: "0.0.0.0/0" },
    # RTP
    { ip_protocol: :udp, min: 32768, max: 65535, cidr_ip: "0.0.0.0/0" },
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
    { ip_protocol: :tcp, min: 5053, max: 5053, group: "internal-sip" },
    { ip_protocol: :tcp, min: 5054, max: 5054, group: "internal-sip" },
    { ip_protocol: :tcp, min: 5058, max: 5058, group: "internal-sip" },
    # Internal SIP (TCP only) - legacy rules
    { ip_protocol: :tcp, min: 5054, max: 5054, group: "bono" },
    { ip_protocol: :tcp, min: 5054, max: 5054, group: "sprout" },
    { ip_protocol: :tcp, min: 5054, max: 5054, group: "perimeta" },
    { ip_protocol: :tcp, min: 5058, max: 5058, group: "bono" },
    { ip_protocol: :tcp, min: 5058, max: 5058, group: "sprout" },
    { ip_protocol: :tcp, min: 5058, max: 5058, group: "perimeta" },
  ]
end

def bono_security_group_rules
  internal_sip_security_group_rules + bono_external_security_group_rules
end

def ibcf_security_group_rules
  []
end

def memento_security_group_rules
  [
    # HTTP
    { ip_protocol: :tcp, min: 443, max: 443, cidr_ip: "0.0.0.0/0" },
    # Cassandra
    { ip_protocol: :tcp, min: 7000, max: 7000, group: "sprout" },
    { ip_protocol: :tcp, min: 9160, max: 9160, group: "sprout" },
  ]
end

def sprout_security_group_rules
  ipsec_security_group_rules + memento_security_group_rules +
    [
      # DEPRECATED: Internal SIP (TCP only) - these should be removed once all
      # deployments are migrated to using internal-sip security groups.
      { ip_protocol: :tcp, min: 5054, max: 5054, group: "bono" },
      { ip_protocol: :tcp, min: 5054, max: 5054, group: "perimeta" },
      { ip_protocol: :tcp, min: 5054, max: 5054, group: "internal-sip" },
      { ip_protocol: :udp, min: 5054, max: 5054, group: "bono" },
      { ip_protocol: :udp, min: 5054, max: 5054, group: "perimeta" },
      { ip_protocol: :udp, min: 5054, max: 5054, group: "internal-sip" },
      { ip_protocol: :tcp, min: 5052, max: 5052, group: "bono" },
      { ip_protocol: :tcp, min: 5052, max: 5052, group: "perimeta" },
      { ip_protocol: :tcp, min: 5052, max: 5052, group: "internal-sip" },
      { ip_protocol: :udp, min: 5052, max: 5052, group: "bono" },
      { ip_protocol: :udp, min: 5052, max: 5052, group: "perimeta" },
      { ip_protocol: :udp, min: 5052, max: 5052, group: "internal-sip" },
      # Memcached interface
      { ip_protocol: :tcp, min: 11211, max: 11211, group: "sprout" },
      # Astaire interface
      { ip_protocol: :tcp, min: 11311, max: 11311, group: "sprout" },
      # Chronos interface
      { ip_protocol: :tcp, min: 7253, max: 7253, group: "sprout" },
      { ip_protocol: :tcp, min: 9888, max: 9888, group: "sprout" },
      # Homestead deregistration interface
      { ip_protocol: :tcp, min: 9888, max: 9888, group: "homestead" },
      # Mangement HTTP API
      { ip_protocol: :tcp, min: 9886, max: 9886, group: "base" },
    ]
end

def homestead_security_group_rules
  ipsec_security_group_rules +
    [
      # API access from sprout/ellis, and restund on bono
      { ip_protocol: :tcp, min: 8888, max: 8888, group: "sprout" },
      { ip_protocol: :tcp, min: 8888, max: 8888, group: "bono" },
      { ip_protocol: :tcp, min: 8888, max: 8889, group: "ellis" },
      # Cassandra
      { ip_protocol: :tcp, min: 7000, max: 7000, group: "homestead" },
      { ip_protocol: :tcp, min: 9160, max: 9160, group: "homestead" },
      # Mangement HTTP API
      { ip_protocol: :tcp, min: 8886, max: 8886, group: "base" },
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

def ralf_security_group_rules
  ipsec_security_group_rules +
    [
      { ip_protocol: :tcp, min: 10888, max: 10888, group: "internal-sip" },
      { ip_protocol: :tcp, min: 10888, max: 10888, group: "ralf" },
      { ip_protocol: :tcp, min: 7253, max: 7253, group: "ralf" },
      # Memcached interface
      { ip_protocol: :tcp, min: 11211, max: 11211, group: "ralf" },
      # Astaire interface
      { ip_protocol: :tcp, min: 11311, max: 11311, group: "sprout" },
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
    # DEPRECATED: Internal SIP (TCP only) - these should be removed once all
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
    # Alarms
    { ip_protocol: :udp, min: 162, max: 162, group: "base" },
    # Traffic from Sprout to the callee
    { ip_protocol: :tcp, min: 5072, max: 5076, group: "internal-sip" },
    { ip_protocol: :tcp, min: 5080, max: 5099, group: "internal-sip" },
    { ip_protocol: :tcp, min: 5180, max: 5183, group: "internal-sip" },
    { ip_protocol: :tcp, min: 5190, max: 5199, group: "internal-sip" }
  ]
end

def hss_security_group_rules
  [
    # Diameter from homestead
    { ip_protocol: :tcp, min: 3868, max: 3868, group: "homestead" },
    { ip_protocol: :tcp, min: 8080, max: 8080, cidr_ip: "0.0.0.0/0" },
  ]
end

def seagull_security_group_rules
  [
    # Diameter from homestead
    { ip_protocol: :tcp, min: 3868, max: 3868, group: "homestead" },
    # Diameter from ralf
    { ip_protocol: :tcp, min: 3869, max: 3869, group: "ralf" },
  ]
end

def cw_aio_security_group_rules
  bono_external_security_group_rules + ellis_security_group_rules +
  [
  ]
end

def reformat_custom_groups(map)
  (map.map do |group, ports|
    [{ ip_protocol: :tcp, min: ports[0], max: ports[1], group: group },
     { ip_protocol: :udp, min: ports[0], max: ports[1], group: group }]
  end).flatten
end

def vellum_node_security_group_rules
  [
    # Astaire/Memcached
    { ip_protocol: :tcp, min: 11211, max: 11211, group: "base" },
    { ip_protocol: :tcp, min: 11311, max: 11311, group: "base" },
    # Chronos
    { ip_protocol: :tcp, min: 7253, max: 7253, group: "base" },
    # Cassandra
    { ip_protocol: :tcp, min: 7000, max: 7000, group: "base" },
    { ip_protocol: :tcp, min: 9888, max: 9888, group: "base" },
    { ip_protocol: :tcp, min: 9160, max: 9160, group: "base" },
    # Etcd
    { ip_protocol: :tcp, min: 2380, max: 2380, group: "base" },
    # Poll Etcd
    { ip_protocol: :tcp, min: 4000, max: 4000, group: "base" },
  ]
end

def clearwater_security_groups(extra_internal_sip_groups)
  {
    "base" => base_security_group_rules,
    "repo" => repo_security_group_rules,
    "bono" => bono_security_group_rules,
    "ibcf" => ibcf_security_group_rules,
    "sprout" => sprout_security_group_rules,
    "homestead" => homestead_security_group_rules,
    "homer" => homer_security_group_rules,
    "ellis" => ellis_security_group_rules,
    "ralf" => ralf_security_group_rules,
    "dns" => dns_security_group_rules,
    "enum" => enum_security_group_rules,
    "cacti" => cacti_security_group_rules,
    "mmonit" => mmonit_security_group_rules,
    "perimeta" => perimeta_security_group_rules,
    "internal-sip" => (internal_sip_security_group_rules +
                       reformat_custom_groups(extra_internal_sip_groups)),
    "plivo" => plivo_security_group_rules,
    "sipp" => sipp_security_group_rules,
    "hss" => hss_security_group_rules,
    "cw_aio" => cw_aio_security_group_rules,
    "seagull" => seagull_security_group_rules,
    "vellum" => vellum_node_security_group_rules
  }
end
