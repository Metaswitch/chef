# @file knife-box-cluster.rb
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

require_relative 'knife-clearwater-utils'
require_relative 'cluster-boxes'

module ClearwaterKnifePlugins
  class BoxCluster < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils
    include ClearwaterKnifePlugins::ClusterBoxes

    banner "box cluster ROLE"

    deps do
      require 'chef'
      require 'fog'
    end

    def run()
      unless name_args.size == 1
        ui.fatal "You need to supply a box role name to cluster"
        show_usage
        exit 1
      end

      role = name_args.first
      cluster_boxes(role)
    end
  end
end
