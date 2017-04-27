# @file chef-base.rb
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

name "chef-base"
description "chef-base role"
run_list [
  "recipe[clearwater::ec2_metadata]",
  "recipe[apt]",
  "recipe[chef-solo-search]",
  "role[security]"
]
default_attributes "clearwater" => {
  # This is the domain name of the DNS zone we create.
  "root_domain" => "example.com",

  # Whether we use a subdomain of the root domain, named automatically
  # after the environment (true), vs. using the root domain itself
  # (false).
  "use_subdomain" => true,

  # Default region to create instances in
  "region" => "us-east-1",

  # Availability zone(s) for load balancers to be created in.
  "availability_zones" => ["us-east-1a", "us-east-1b"],

  # URL for Clearwater debian repo server
  "repo_servers" => ["http://repo.cw-ngv.com/stable"],

  # Number of numbers to put into number pool in ellis
  "number_start" => "6505550000",
  "number_count" => 100,
  "pstn_number_start" => "2125550100",
  "pstn_number_count" => 10,

  # TTL (in seconds) for the DNS entries. Since we use DNS records for load-
  # balancing, we need to keep this low.  5 minutes is the smallest value Route53
  # allows so we'll use that until we test on other clouds.
  "dns_ttl" => 300,

  # Sas server to use. To disable SAS, set to "0.0.0.0".
  "sas_server" => "0.0.0.0",

  # Splunk server to use. To disable splunk, set an invalid host, e.g. "0.0.0.0"
  "splunk_server" => "0.0.0.0",

  # ENUM server to use.  To use the default (public) servers, specify "localhost".
  "enum_server" => nil,

  # Trusted SIP trunking peers to accept calls from. Specify an array of IP addresses.
  "trusted_peers" => [],

  # Signup key. Anyone with this key can create accounts
  # on the deployment. Set to a secure value.
  "signup_key"      => "CHANGE_ME_IN_THE_ENVIRONMENT",

  # TURN workaround password, used by faulty WebRTC clients.
  # Anyone with this password can use the deployment to send
  # arbitrary amounts of data. Set to a secure value.
  "turn_workaround" => "CHANGE_ME_IN_THE_ENVIRONMENT",

  # Ellis API key. Used by internal scripts and live tests to
  # provision, update and delete user accounts without a password.
  # Set to a secure value.
  "ellis_api_key"  => "CHANGE_ME_IN_THE_ENVIRONMENT",

  # Ellis cookie key. Used to prevent spoofing of Ellis cookies. Set
  # to a secure value.
  "ellis_cookie_key" => "CHANGE_ME_IN_THE_ENVIRONMENT",

  # Secret keys for Homestead-stored passwords. Set to a secure value.
  "homestead_password_encryption_key" => "CHANGE_ME_IN_THE_ENVIRONMENT",

  # Cassandra hostname for both homer and homestead.
  "cassandra_hostname" => "localhost",

  # HSS configuration settings.
  "hss_hostname" => "0.0.0.0",
  "hss_port" => 3868,

  # SMTP credentials as supplied by your email provider.
  # Only required for password recovery function.
  "smtp_server"     => "localhost",
  "smtp_username"   => "",
  "smtp_password"   => "",

  # Sender to use for password recovery emails. For some
  # SMTP servers (e.g., Amazon SES) this email address
  # must be validated or email sending will fail.
  "email_sender"    => "nobody@example.com",

  # DNS server configuration - internal subnet to forward requests from and
  # DNS forwarder to use when doing so.
  "dns_internal_subnet" => "10.0.0.0/8",
  "dns_forwarder" => "10.0.0.1",

  # Split-storage architecture
  "split_storage" => true,
}
