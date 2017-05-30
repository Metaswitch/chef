# @file chef-base.rb
#
# Copyright (C) Metaswitch Networks 2016
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

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
}
