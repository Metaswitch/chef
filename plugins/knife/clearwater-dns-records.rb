#!/usr/bin/env ruby

# @file clearwater-dns-records.rb
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

require_relative 'boxes'

def dns_records
  dns = {}
  base_dns = {
    "sprout" => {
      :type  => "A",
      :value => ipv4s_local(find_active_nodes("sprout")),
      :ttl   => "60"
    },

   "_sip._tcp.sprout" => {
      :type  => "SRV",
      :value => scscf_srv_flat(find_active_nodes("sprout")),
      :ttl   => "60"
    },

   "_sip._tcp.sprout-icscf" => {
      :type  => "SRV",
      :value => icscf_srv_flat(find_active_nodes("sprout")),
      :ttl   => "60"
    },

    "hs" => {
      :type  => "A",
      :value => ipv4s_local(find_active_nodes("homestead")),
      :ttl   => "60"
    },

    "homer" => {
      :type  => "A",
      :value => ipv4s_local(find_active_nodes("homer")),
      :ttl   => "60"
    },

    "ellis" => {
      :type => "A",
      :value => ipv4s(find_active_nodes("ellis")),
    },
  }

  if attributes["num_gr_sites"] && attributes["num_gr_sites"] > 1
    number_of_sites = attributes["num_gr_sites"]
    for i in 0...number_of_sites
      base_gr_dns = {
        "hs-site#{i}" => {
          :type  => "A",
          :value => ipv4s_local_site(find_active_nodes("homestead"), i, number_of_sites),
          :ttl   => "60"
        },

        "homer-site#{i}" => {
          :type  => "A",
          :value => ipv4s_local_site(find_active_nodes("homer"), i, number_of_sites),
          :ttl   => "60"
        },

        "_sip._tcp.sprout-site#{i}" => {
          :type  => "SRV",
          :value => scscf_srv_site(find_active_nodes("sprout"), i, number_of_sites),
          :ttl   => "60"
        },

        "_sip._tcp.sprout-icscf-site#{i}" => {
          :type  => "SRV",
          :value => icscf_srv_site(find_active_nodes("sprout"), i, number_of_sites),
          :ttl   => "60"
        },
      }
      base_dns = base_dns.merge(base_gr_dns)
    end
  end

  bono_dns = {
    "" => {
      :type  => "A",
      :value => ipv4s(find_active_nodes("bono")),
      :ttl   => "60"
    },
  }

  ralf_dns = {
    "ralf" => {
      :type  => "A",
      :value => ipv4s_local(find_active_nodes("ralf")),
      :ttl   => "60"
    }
  }

  if attributes["num_gr_sites"] && attributes["num_gr_sites"] > 1
    number_of_sites = attributes["num_gr_sites"]
    for i in 0...number_of_sites
      ralf_gr_dns = {
        "ralf-site#{i}" => {
          :type  => "A",
          :value => ipv4s_local_site(find_active_nodes("ralf"), i, number_of_sites),
          :ttl   => "60"
        }
      }
    end
    ralf_dns = ralf_dns.merge(ralf_gr_dns)
  end

  memento_dns = {
    "memento" => {
      :type  => "A",
      :value => ipv4s_local(find_active_nodes("memento")),
      :ttl   => "60"
    },

    "mementohttp" => {
      :type  => "A",
      :value => ipv4s(find_active_nodes("memento")),
      :ttl   => "60"
    },
  }

  seagull_dns = {
    "cdf.seagull" => {
      :type  => "A",
      :value => ipv4s_local(find_active_nodes("seagull")),
      :ttl   => "60"
    },

    "hss.seagull" => {
      :type  => "A",
      :value => ipv4s_local(find_active_nodes("seagull")),
      :ttl   => "60"
    },
  }

  dns = dns.merge(base_dns)
  if find_active_nodes("bono").length > 0
    dns = dns.merge(bono_dns)
  end
  if find_active_nodes("ralf").length > 0
    dns = dns.merge(ralf_dns)
  end
  if find_active_nodes("memento").length > 0
    dns = dns.merge(memento_dns)
  end
  if find_active_nodes("seagull").length > 0
    dns = dns.merge(seagull_dns)
  end

  return dns
end

def in_site?(n, site, number_of_sites)
  (n[:clearwater][:index] || 1) % number_of_sites == site
end

def ipv4s(boxes)
  boxes.map {|n| n[:cloud][:public_ipv4]}
end

def ipv4s_local(boxes)
  boxes.map {|n| n[:cloud][:local_ipv4]}
end

def ipv4s_local_site(boxes, site, number_of_sites)
  boxes.select { |n| in_site?(n, site, number_of_sites) }.map {|n| n[:cloud][:local_ipv4]}
end

def icscf_srv_site(boxes, site, number_of_sites)
  boxes.map  do |n|
    priority = if in_site?(n, site, number_of_sites) then 1 else 2 end
    "#{priority} 1 5052 #{n[:cloud][:local_hostname]}"
  end
end

def scscf_srv_site(boxes, site, number_of_sites)
  boxes.map  do |n|
    priority = if in_site?(n, site, number_of_sites) then 1 else 2 end
    "#{priority} 1 5054 #{n[:cloud][:local_hostname]}"
  end
end

def icscf_srv_flat(boxes)
  boxes.map  do |n|
    priority = 1
    "#{priority} 1 5052 #{n[:cloud][:local_hostname]}"
  end
end

def scscf_srv_flat(boxes)
  boxes.map  do |n|
    priority = 1
    "#{priority} 1 5054 #{n[:cloud][:local_hostname]}"
  end
end

def public_hostnames(boxes)
  boxes.map {|n| n[:cloud][:public_hostname] + "."}
end
