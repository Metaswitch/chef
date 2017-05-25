# @file cacti.rb
#
# Copyright (C) Metaswitch Networks
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

package "cacti" do
  action [:install]
  options "--force-yes"
end

package "cacti-spine" do
  action [:install]
  options "--force-yes"
end

remote_directory '/usr/share/clearwater/cacti' do
  source 'cacti'
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

execute 'reset_database' do
  command 'mysql cacti < /usr/share/clearwater/cacti/cactidb.sql'
  user 'root'
end

execute 'import_templates' do
  cwd '/usr/share/cacti/cli'
  command 'find /usr/share/clearwater/cacti/templates -type f -exec php ./import_template.php --filename={} --with-template-rras \;'
  user 'root'
end

