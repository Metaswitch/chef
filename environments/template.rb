name "<name>"
description "Clearwater deployment - <name>"
cookbook_versions "clearwater" => "= 0.1.0"
override_attributes "clearwater" => {
  "root_domain" => "<zone>",
  "availability_zones" => ["us-east-1a", "us-east-1b"],
  "repo_server" => "http://repo.cw-ngv.com/latest",
  "number_start" => "6505550000",
  "number_count" => 1000,
  "keypair" => "<keypair_name>",
  "keypair_dir" => "~/.chef/",
  "pstn_number_count" => 0,
  "hss_hostname" => "0.0.0.0",
  "hss_port" => 3868,
  "hss_realm" => nil,
  "billing_realm" => nil,
  "cassandra_hostname" => "localhost",
}
