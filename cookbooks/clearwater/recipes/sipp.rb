# @file sipp.rb
#
# Copyright (C) Metaswitch Networks 2016
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

bonos = search(:node,
               "role:bono AND chef_environment:#{node.chef_environment}")
bonos.sort! { |a,b| a[:clearwater][:index] <=> b[:clearwater][:index] }
bonos.map! { |n| n[:cloud][:local_ipv4] }

package "clearwater-sip-stress" do
  action [:install]
  options "--force-yes"
end

package "clearwater-sip-stress-coreonly" do
  action [:install]
  options "--force-yes"
end

package "clearwater-sip-stress-stats" do
  action [:install]
  options "--force-yes"
end
