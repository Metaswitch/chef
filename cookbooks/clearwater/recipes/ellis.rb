# @file ellis.rb
#
# Copyright (C) Metaswitch Networks 2016
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

package "ellis" do
  action [:install]
  options "--force-yes"
end

# Perform daily backup of database
cron "backup" do
  minute 0
  hour 0
  command "/usr/share/clearwater/ellis/backup/do_backup.sh"
end

# Create number pools (first normal, then PSTN)
execute "infra_script" do
  command "service clearwater-infrastructure restart"
  user "root"
  only_if { ::File.exists?('/etc/clearwater/shared_config') }
  notifies :run, "execute[create_numbers]", :immediately
  notifies :run, "execute[create_pstn_numbers]", :immediately
end

execute "create_numbers" do
  cwd "/usr/share/clearwater/ellis/"
  command "env/bin/python src/metaswitch/ellis/tools/create_numbers.py --start #{node[:clearwater][:number_start]} --count #{node[:clearwater][:number_count]}"
  user "root"
  action :nothing
end

execute "create_pstn_numbers" do
  cwd "/usr/share/clearwater/ellis/"
  command "env/bin/python src/metaswitch/ellis/tools/create_numbers.py --start #{node[:clearwater][:pstn_number_start]} --count #{node[:clearwater][:pstn_number_count]} --pstn"
  user "root"
  action :nothing
end
