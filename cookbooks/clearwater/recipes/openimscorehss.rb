# @file openimscorehss.rb
#
# Copyright (C) Metaswitch Networks
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

# Tell apt about the repository server.
apt_repository 'fhoss' do
  uri          'http://ppa.launchpad.net/rkd-u/fhoss/ubuntu'
  arch         'amd64'
  distribution 'precise'
  components   ['main']
end

# Install the package, using a response_file to configure it with our IP and home domain
package "openimscore-fhoss" do
    action [:install]
    response_file 'openimscorehss/debian.preseed.erb'
    options "--force-yes"
end

# Fix up the users so that we just have hssAdmin with a password of the signup key
template "/usr/share/java/fhoss-0.2/conf/tomcat-users.xml" do
  mode "0644"
  source "openimscorehss/users.xml"
  # Restart to pick up that password change
  notifies :restart, "service[openimscore-fhoss]", :immediately
end

service "openimscore-fhoss" do
  action :nothing
end
