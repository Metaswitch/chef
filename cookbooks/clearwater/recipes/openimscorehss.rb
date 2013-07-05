# @file openimscorehss.rb
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

package "subversion" do
  action [:install]
  options "--force-yes"
end

package "mysql-server" do
  action [:install]
  options "--force-yes"
end

package "libmysqlclient-dev" do
  action [:install]
  options "--force-yes"
end

package "libxml2" do
  action [:install]
  options "--force-yes"
end

package "libxml2-dev" do
  action [:install]
  options "--force-yes"
end

package "bind9" do
  action [:install]
  options "--force-yes"
end

package "flex" do
  action [:install]
  options "--force-yes"
end

package "bison" do
  action [:install]
  options "--force-yes"
end

package "libcurl4-openssl-dev" do
  action [:install]
  options "--force-yes"
end

package "openjdk-7-jre-headless" do
  action [:install]
  options "--force-yes"
end

package "openjdk-7-jdk" do
  action [:install]
  options "--force-yes"
end

package "ant" do
  action [:install]
  options "--force-yes"
end

directory "/opt/OpenIMSCore" do
end

execute "svn" do
  cwd "/opt/OpenIMSCore"
  command "svn checkout http://svn.berlios.de/svnroot/repos/openimscore/FHoSS/trunk FHoSS"
end

execute "mysql" do
  command "mysql -uroot --password= </opt/OpenIMSCore/FHoSS/scripts/hss_db.sql && mysql -uroot --password= </opt/OpenIMSCore/FHoSS/scripts/userdata.sql"
end

execute "ant" do
  cwd "/opt/OpenIMSCore/FHoSS"
  environment ({ "JAVA_TOOL_OPTIONS" => "-Dfile.encoding=UTF-8" })
  command "ant compile deploy"
end

domain = if node[:clearwater][:use_subdomain]
           node.chef_environment + "." + node[:clearwater][:root_domain]
         else
           node[:clearwater][:root_domain]
         end

template "/opt/OpenIMSCore/FHoSS/deploy/DiameterPeerHSS.xml" do
  mode "0644"
  source "openimscorehss/DiameterPeerHSS.xml.erb"
  variables domain: domain,
            node: node
end

cookbook_file "/etc/init.d/openimscorehss" do
  mode "0755"
  source "openimscorehss/openimscorehss.init.d"
  owner "root"
  group "root"
end

service "openimscorehss" do
  action :start
end
