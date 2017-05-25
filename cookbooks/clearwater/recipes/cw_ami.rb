# @file cw_ami.rb
#
# Copyright (C) Metaswitch Networks
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

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
