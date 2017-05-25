# @file security.rb
#
# Copyright (C) Metaswitch Networks
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

directory "/etc/apt/certs/clearwater" do
  owner "root"
  group "root"
  mode "0755"
  action :create
  recursive true
  notifies :run, "ruby_block[get-secret-key]", :immediately
  notifies :create, "template[/etc/apt/apt.conf.d/45_clearwater_repo]", :immediately
  only_if { node[:clearwater][:repo_servers].any? { |rs| URI(rs).scheme == "https" } }
end

ruby_block "get-secret-key" do
  block do
    keys = Chef::EncryptedDataBagItem.load("repo_keys", "generic")
    File.open("/etc/apt/certs/clearwater/repository-ca.crt",'w') { |f|
      f.write(keys["repository-ca.crt"])
    }
    File.open("/etc/apt/certs/clearwater/repository-server.crt",'w') { |f|
      f.write(keys["repository-server.crt"])
    }
    File.open("/etc/apt/certs/clearwater/repository-server.key",'w') { |f|
      f.write(keys["repository-server.key"])
    }
  end
  action :nothing
end

# Tell apt about the Clearwater repository server's security keys'.
template "/etc/apt/apt.conf.d/45_clearwater_repo" do
  mode "0644"
  source "apt.keys.erb"
  variables repo_hosts: node[:clearwater][:repo_servers].select { |rs| URI(rs).scheme == "https" }.map { |rs| URI(rs).host }
  action :nothing
end

# Tell apt about the Clearwater repository server.
template "/etc/apt/sources.list.d/clearwater.list" do
  mode "0644"
  source "apt.list.erb"
  variables hostnames: node[:clearwater][:repo_servers],
            repos: ["binary/"]
  notifies :run, "execute[apt-key-clearwater]", :immediately
end

# Fetch the key for the Clearwater repository server
execute "apt-key-clearwater" do
  user "root"
  command "curl -L http://repo.cw-ngv.com/repo_key | sudo apt-key add -"
  action :nothing
end

# Make sure all packages are up to date (note this uses an external cookbook, in cookbooks/apt)
execute "apt-get update" do
  action :nothing
  subscribes :run, "execute[apt-key-clearwater]", :immediately
end

