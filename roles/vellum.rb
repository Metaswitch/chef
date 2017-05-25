# @file vellum.rb
#
# Copyright (C) Metaswitch Networks
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

name "vellum"
description "vellum role"
run_list [
  "role[clearwater-base]",
  "role[alarms]",
  "recipe[clearwater::chronos]",
  "recipe[clearwater::vellum]",
  "role[clearwater-etcd]"
]
