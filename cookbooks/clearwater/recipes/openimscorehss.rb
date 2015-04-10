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

# Tell apt about the repository server.
cookbook_file "/etc/apt/sources.list.d/fhoss.list" do
  mode "0644"
  source "openimscorehss/fhoss.apt.list"
end

execute "apt-get update" do
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
end

# Restart to pick up that password change
service "openimscore-fhoss" do
  action :restart
end
