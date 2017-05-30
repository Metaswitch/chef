# @file base.rb
#
# Copyright (C) Metaswitch Networks 2013
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

# When Chef bootstraps itself onto a node it creates these
# config files which means subsequent bootstraps will not happen
#
# As this recipe is for creating a image with a ubuntu install,
# nuke these files - creating an image with Chef without the credentials
cookbook_file "/etc/chef/client.rb" do
  action :delete
end

cookbook_file "/etc/chef/client.pem" do
  action :delete
end
