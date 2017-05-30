# @file sprout.rb
#
# Copyright (C) Metaswitch Networks 2017
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

if node[:clearwater][:custom_sprout_package]
  package node[:clearwater][:custom_sprout_package] do
    action [:install]
    options "--force-yes"
  end
else
  package "sprout" do
    action [:install]
    options "--force-yes"
  end
end

package "clearwater-snmpd" do
  action [:install]
  options "--force-yes"
end

domain = if node[:clearwater][:use_subdomain]
           node.chef_environment + "." + node[:clearwater][:root_domain]
         else
           node[:clearwater][:root_domain]
         end

