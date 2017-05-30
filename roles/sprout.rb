# @file sprout.rb
#
# Copyright (C) Metaswitch Networks 2016
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

name "sprout"
description "sprout role"
run_list [
  "role[clearwater-base]",
  "role[alarms]",
  "recipe[clearwater::sprout]",
  "role[clearwater-etcd]"
]

override_attributes "clearwater" => {
  "gemini" => 5055,
  "memento" => 5055,
  "cdiv" => 5055,
}
