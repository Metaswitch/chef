# @file ellis.rb
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
execute "create_numbers" do
  cwd "/usr/share/clearwater/ellis/"
  command "env/bin/python src/metaswitch/ellis/tools/create_numbers.py --start #{node[:clearwater][:number_start]} --count #{node[:clearwater][:number_count]}"
  user "root"
  only_if { ::File.exists?('/etc/clearwater/shared_config') }
end

execute "create_pstn_numbers" do
  cwd "/usr/share/clearwater/ellis/"
  command "env/bin/python src/metaswitch/ellis/tools/create_numbers.py --start #{node[:clearwater][:pstn_number_start]} --count #{node[:clearwater][:pstn_number_count]} --pstn"
  user "root"
  only_if { ::File.exists?('/etc/clearwater/shared_config') }
end
