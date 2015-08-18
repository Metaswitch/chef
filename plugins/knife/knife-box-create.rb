# @file knife-box-create.rb
#
# Project Clearwater - IMS in the Cloud
# Copyright (C) 2013  Metaswitch Networks Ltd
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version, along with the "Special Exception" for use of
# the program along with SSL, set forth below. This program is distributed
# in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details. You should have received a copy of the GNU General Public
# License along with this program.  If not, see
# <http://www.gnu.org/licenses/>.
#
# The author can be reached by email at clearwater@metaswitch.com or by
# post at Metaswitch Networks Ltd, 100 Church St, Enfield EN2 6BQ, UK
#
# Special Exception
# Metaswitch Networks Ltd  grants you permission to copy, modify,
# propagate, and distribute a work formed by combining OpenSSL with The
# Software, or a work derivative of such a combination, even if such
# copying, modification, propagation, or distribution would otherwise
# violate the terms of the GPL. You must comply with the GPL in all
# respects for all of the code used other than OpenSSL.
# "OpenSSL" means OpenSSL toolkit software distributed by the OpenSSL
# Project and licensed under the OpenSSL Licenses, or a work based on such
# software and licensed under the OpenSSL Licenses.
# "OpenSSL Licenses" means the OpenSSL License and Original SSLeay License
# under which the OpenSSL Project distributes the OpenSSL toolkit software,
# as those licenses appear in the file LICENSE-OPENSSL.

require_relative 'knife-clearwater-utils'
require_relative 'boxes'
require_relative 'knife-box-delete'

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

    option :image_name,
      :long => "--image_name IMAGE_NAME",
      :default => "Clearwater AMI",
      :description => "Name to use when creating an EC2 AMI",
      :proc => (Proc.new do |arg|
        unless arg =~ /^[A-Za-z0-9,\/_() -]{3,128}$/
          Chef::Log.error "Image name must be between 3 and 128 characters long, and may contain letters, numbers, spaces, '(', ')', '.', '-', '/' and '_'"
          exit 2
        end
      end)

    option :ralf,
      :long => "--with-ralf",
      :boolean => true,     
      :default => false,
      :description => "Does this deployment have a Ralf?"

    def run(supported_boxes = [])
      unless name_args.size == 1
        ui.fatal "You need to supply a box role name"
        show_usage
        exit 1
      end
      role = name_args.first

      if supported_boxes != []
        box_manager = Clearwater::BoxManager.new(config[:cloud].to_sym, env, attributes, {}, supported_boxes)
      else
        box_manager = Clearwater::BoxManager.new(config[:cloud].to_sym, env, attributes)
      end

      new_box = box_manager.create_box(role, {index: config[:index], ralf: ((role == "ralf") || config[:ralf]), seagull: config[:seagull]})
      instance_id = new_box.id

      if role == "cw_ami"
        ec2_conn = Fog::Compute::AWS.new(Chef::Config[:knife].select { |k, v| [:aws_secret_access_key, :aws_access_key_id].include? k })
        ec2_conn.stop_instances(instance_id)
        print "\nStopping the instance in preparation for making an AMI"
        Fog.wait_for do
          print "."
          ec2_conn.describe_instances('instance-id' => instance_id).body["reservationSet"].first["instancesSet"].first["instanceState"]["name"] == "stopped"
        end
        puts "done"

        result = ec2_conn.create_image(instance_id, config[:image_name], "This AMI contains a Project Clearwater all-in-one node running on Ubuntu 12.04.2")
        print "Creating the AMI"
        image_id = result.body["imageId"]

        Fog.wait_for(1800, 5) do
          print "."
          ec2_conn.describe_images('ImageId' => image_id).body['imagesSet'].first['imageState'] == "available"
        end
        puts "done"
        puts "\nAMI #{image_id} is available"

        puts "\nTerminating the instance"
        box_delete = BoxDelete.new("-E #{env.name}".split)
        box_delete.name_args=["#{new_box.tags["Name"]}"]
        box_delete.config[:yes] = true
        box_delete.config[:verbosity] = config[:verbosity]
        box_delete.run(true)
      end
    end
  end
end
