# @file clearwater-infrastructure.rb
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

name "clearwater-infrastructure"
description "clearwater-infrastructure role"
run_list [
  "recipe[clearwater::ec2_metadata]",
  "recipe[apt]",
  "recipe[clearwater::infrastructure]"
]
default_attributes "clearwater" => {
  # This is the domain name of the DNS zone we create.
  "root_domain" => "example.com",

  # Default region to create instances in
  "region" => "us-east-1",

  # Availability zone(s) for load balancers to be created in.
  "availability_zones" => ["us-east-1a", "us-east-1b"],

  # URL for Clearwater debian repo server
  "repo_server" => "http://repo.cw-ngv.com/stable",

  # Number of numbers to put into number pool in ellis
  "number_start" => "6505550000",
  "number_count" => 100,
  "pstn_number_start" => "2125550100",
  "pstn_number_count" => 10,

  # TTL (in seconds) for the DNS entries. Since we use DNS records for load-
  # balancing, we need to keep this low.  5 minutes is the smallest value Route53
  # allows so we'll use that until we test on other clouds.
  "dns_ttl" => 300,

  # Sas server to use. To disable SAS, set to an invalid host, e.g "locahost"
  "sas_server" => "localhost",

  # Splunk server to use. To disable splunk, set an invalid host, e.g. "0.0.0.0"
  "splunk_server" => "0.0.0.0",

  # ENUM server to use.  To use the default (public) servers, specify "localhost".
  "enum_server" => "localhost",

  #
  # The following values should be set in knife.rb; we copy them into
  # the role here.
  #

  # Signup key. Anyone with this key can create accounts
  # on the deployment. Set to a secure value.
  "signup_key"      => Chef::Config[:knife][:signup_key],

  # TURN workaround password, used by faulty WebRTC clients.
  # Anyone with this password can use the deployment to send
  # arbitrary amounts of data. Set to a secure value.
  "turn_workaround" => Chef::Config[:knife][:turn_workaround],

  # Ellis API key. Used by internal scripts and live tests to
  # provision, update and delete user accounts without a password.
  # Set to a secure value.
  "ellis_api_key"  => Chef::Config[:knife][:ellis_api_key],

  # Ellis cookie key. Used to prevent spoofing of Ellis cookies. Set
  # to a secure value.
  "ellis_cookie_key" => Chef::Config[:knife][:ellis_cookie_key],

  # SMTP credentials as supplied by your email provider.
  # Only required for password recovery function.
  "smtp_server"     => Chef::Config[:knife][:smtp_server],
  "smtp_username"   => Chef::Config[:knife][:smtp_username],
  "smtp_password"   => Chef::Config[:knife][:smtp_password],

  # Sender to use for password recovery emails. For some
  # SMTP servers (e.g., Amazon SES) this email address
  # must be validated or email sending will fail.
  "email_sender"    => Chef::Config[:knife][:email_sender],

  # MMonit server credentials, if any.
  "mmonit_server"   => Chef::Config[:knife][:mmonit_server],
  "mmonit_username" => Chef::Config[:knife][:mmonit_username],
  "mmonit_password" => Chef::Config[:knife][:mmonit_password],

  # DNS server configuration - internal subnet to forward requests from and
  # DNS forwarder to use when doing so.
  "dns_internal_subnet" => "10.0.0.0/8",
  "dns_forwarder" => "10.0.0.1",
}
