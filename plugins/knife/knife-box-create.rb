# @file knife-box-create.rb
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
require_relative 'boxes'

module ClearwaterKnifePlugins
  class BoxCreate < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils

    deps do
      require 'chef'
      require 'fog'
    end

    banner "box create ROLE_NAME"

    option :index,
      :long => "--index INDEX",
      :description => "Index of node to create, will be appended to the node name",
      :proc => Proc.new { |arg| Integer(arg) rescue begin Chef::Log.error "--index must be an integer"; exit 2 end }

    option :cloud,
      :long => "--cloud CLOUD",
      :default => "ec2",
      :description => "Cloud to create box in. Currently support: #{Clearwater::BoxManager.supported_clouds.join ', '}",
      :proc => (Proc.new do |arg|
        unless Clearwater::BoxManager.supported_clouds.include? arg.to_sym
          Chef::Log.error "#{arg} is not a supported cloud"
          exit 2
        end
      end)

    def run()
      unless name_args.size == 1
        ui.fatal "You need to supply a box role name"
        show_usage
        exit 1
      end
      role = name_args.first

      unless Clearwater::BoxManager.supported_roles.include? role
        ui.fatal "#{role} is not a supported box role"
        exit 1
      end

      flavor_overrides = {
        bono: nil, # or bono: "m1.large" etc...
        ellis: nil,
        homestead: nil,
        homer: nil,
        sprout: nil,
        ibcf: nil,
        dns: nil,
        sipp: nil,
        enum: nil,
        cacti: nil
      }

      box_manager = Clearwater::BoxManager.new(config[:cloud].to_sym, env, attributes)
      box_manager.create_box(role, {index: config[:index], flavor: flavor_overrides[role.to_sym]})
    end
  end
end
