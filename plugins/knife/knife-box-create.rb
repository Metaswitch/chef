# @file knife-box-create.rb
#
# Copyright (C) Metaswitch Networks 2016
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

require_relative 'knife-clearwater-utils'
require_relative 'boxes'
require_relative 'knife-box-delete'
require_relative 'trigger-chef-client'

module ClearwaterKnifePlugins
  class BoxCreate < Chef::Knife
    include ClearwaterKnifePlugins::ClearwaterUtils
    include ClearwaterKnifePlugins::TriggerChefClient

    deps do
      require 'chef'
      require 'fog'
    end

    banner "box create ROLE_NAME"

    option :site,
      :long => "--site SITE",
      :description => "Site of node to create, will be appended to the node name",
      :proc => Proc.new { |arg| Integer(arg) rescue begin Chef::Log.error "--index must be an integer"; exit 2 end }

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

    option :standalone,
      :long => "--standalone",
      :boolean => true,
      :default => false,
      :description => "Used if there are no boxes in this deployment already"

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

      new_box = box_manager.create_box(role, {site: config[:site], index: config[:index], ralf: ((role == "ralf") || config[:ralf]), seagull: config[:seagull]})
      instance_id = new_box.id

      if config[:standalone]
        # The box is a standalone box, so add it now to the etcd cluster,
        # and create the shared configuration
        boxes = find_nodes(chef_environment: config[:environment])
        if boxes.size == 1
          # Check that there's only one box in this environment; if there's
          # more then we shouldn't be overriding any etcd settings
          print "Box is standalone, so updating etcd configuration\n"
          boxes[0].set[:clearwater][:etcd_cluster] = true
          boxes[0].run_list << "role[shared_config]"
          boxes[0].save
          trigger_chef_client(config[:cloud],
                              "chef_environment:#{config[:environment]}")
        else
          print "Can't use standalone on an existing deployment. No changes have been made to etcd configuration\n"
        end
      end

      if role == "cw_aio"
        puts "Note: The signup code for AIO nodes is 'secret', not the value configured in your environment file"
      end

      if role == "cw_ami"
        ec2_conn = Fog::Compute::AWS.new(Chef::Config[:knife].select { |k, v| [:aws_secret_access_key, :aws_access_key_id].include? k })
        ec2_conn.stop_instances(instance_id)
        print "\nStopping the instance in preparation for making an AMI"
        Fog.wait_for do
          print "."
          ec2_conn.describe_instances('instance-id' => instance_id).body["reservationSet"].first["instancesSet"].first["instanceState"]["name"] == "stopped"
        end
        puts "done"

        result = ec2_conn.create_image(instance_id, config[:image_name], "This AMI contains a Project Clearwater all-in-one node running on Ubuntu 14.04")
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
        box_delete.run()
      end
    end
  end
end
