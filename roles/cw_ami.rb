# @file cw_ami.rb
#
# Copyright (C) Metaswitch Networks 2013
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

name "cw_ami"
description "cw_ami role"
run_list [
  "role[cw_aio]",
  "recipe[clearwater::cw_ami]"
]

override_attributes "clearwater" => {
  "signup_key" => "secret"
}

