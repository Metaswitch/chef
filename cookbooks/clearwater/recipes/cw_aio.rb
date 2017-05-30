# @file cw_aio.rb
#
# Copyright (C) Metaswitch Networks 2016
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

# Install all the clearwater packages. Use the AWS configuration package

execute "install-clearwater-aio" do
  user "root"
  command "curl -L https://raw.githubusercontent.com/Metaswitch/clearwater-infrastructure/master/scripts/clearwater-aio-install.sh | sudo bash -s clearwater-auto-config-aws #{node[:clearwater][:repo_servers].first} #{node[:clearwater][:repo_servers].first} #{node[:clearwater][:number_start]} #{node[:clearwater][:number_count]}"
end
