# @file homer.rb
#
# Copyright (C) Metaswitch Networks
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

package "homer" do
  action [:install]
  options "--force-yes"
end

# Perform daily backup of database
cron "backup" do
  hour 0
  minute 0
  command "/usr/share/clearwater/bin/run-in-signaling-namespace /usr/share/clearwater/bin/do_backup.sh homer"
end
