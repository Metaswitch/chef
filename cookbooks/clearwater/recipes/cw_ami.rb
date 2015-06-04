# @file cw_ami.rb
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

# The steps in this recipe anonymise the current system, removing any
# potentially dangerous/private information from the newly built image
# prior to capturing an AMI from it.  
# The steps are based onm those recommended in the EC2 documentation,

# Change Permit Root Login
bash "change_permit_root_login" do
  user "root"
  code "sed -i -e 's/PermitRootLogin yes/PermitRootLogin without-password/g' /etc/ssh/sshd_config"
end

# Remove SSH key pairs
bash "remove_ssh_key_pairs" do
  user "root"
  code 'find /etc/ssh/ssh_host_*key*  -exec rm -f {} \; || true'
end

# Delete shell histories
bash "remove_shell_histories" do
  user "root"
  code 'find /root/.*history /home/*/.*history -exec rm -f {} \; || true'
end

# Remove authorized keys
bash "remove_authorized_keys" do
  user "root"
  code 'find / -name authorized_keys -exec rm -f {} \; || true'
end

# It is not possible to delete the credentials used by chef at this point as chef will 
# immediately fail. Such files are deleted from the clearwater-auto-config init.d when
# the server goes down, which will be the next step in creating an AMI.
