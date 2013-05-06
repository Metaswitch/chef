# @file ibcf.rb
#
# Copyright (C) 2013  Metaswitch Networks Ltd
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# The author can be reached by email at clearwater@metaswitch.com or by post at
# Metaswitch Networks Ltd, 100 Church St, Enfield EN2 6BQ, UK

# For now, all the IBCF data is hardcoded as we only use it on a single system - dogfood
# The IBCF node is not configure as part of knife deployment create, instead
# it must be manually added. This isn't great, but given that PSTN interconnect
# is a manual process we'll live with it for now
template "/etc/clearwater/user_settings" do
  mode "0644"
  source "ibcf/user_settings.erb"
end
