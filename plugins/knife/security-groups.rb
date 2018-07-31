#!/usr/bin/env ruby

# @file security-groups.rb
#
# Copyright (C) Metaswitch Networks 2015
# If license terms are provided to you in a COPYING file in the root directory
# of the source code repository by which you are accessing this code, then
# the license outlined in that COPYING file applies to your use.
# Otherwise no rights are granted except for those provided to you by
# Metaswitch Networks in a separate written agreement.

require 'fog'

module Clearwater
  module SecurityGroups
    # Since AWS ICMP ports are not really ranges, use this class to pass port ranges to authorise_port_range.
    class PortRangeObject
      attr_accessor :min, :max
      def initialize(rule)
        @min = rule[:min]
        @max = rule[:max]
      end
    end

    # Find or create a Security Group by name.
    def find_or_create_group(name, vpc_id, description = "")
      name = "#{name}-#{vpc_id}" unless vpc_id.nil?
      sg = sg_api.get(name)
      if sg.nil?
        puts "Creating security group: #{name}"
        if vpc_id.nil?
          sg = sg_api.new(name: name,
                          description: description)
        else
          sg = sg_api.new(name: name,
                          vpc_id: vpc_id,
                          description: description)
        end
        sg.save
        sg.reload
      end
      return sg
    end

    # Find a Security Group by name.
    def find_group(name, vpc_id)
      name = "#{name}-#{vpc_id}" unless vpc_id.nil?
      return sg_api.get(name)
    end

    # Add a single rule to a group.
    #
    # Warning: Group is not updated by this command, to update the local view of the group, call group.reload.
    def add_security_group_rule(group, rule)
      Chef::Log.info "Adding rule #{rule} to #{group.name}"
      group.authorize_port_range(PortRangeObject.new(rule), rule)
      sleep 1
    end

    # Add a list of rules to a group.
    #
    # Warning: Group is not updated by this command, to update the local view of the group, call group.reload.
    def add_security_group_rules(group, rules)
      rules.each do |rule|
        add_security_group_rule(group, rule)
      end
    end

    # Remove a single rule from a group.
    #
    # Warning: Group is not updated by this command, to update the local view of the group, call group.reload.
    def remove_security_group_rule(group, rule)
      Chef::Log.info "Revoking rule #{rule} from #{group.name}"
      group.revoke_port_range(PortRangeObject.new(rule), rule)
      sleep 1
    end

    # Remove a list of rules from a group.
    #
    # Warning: Group is not updated by this command, to update the local view of the group, call group.reload.
    def remove_security_group_rules(group, rules)
      rules.each do |rule|
        remove_security_group_rule(group, rule)
      end
    end

    # Commission a single given security group.  The group options should include :min and :max (for the port range), :ip_protocol (tcp, udp or icmp) and :group OR :cidr_ip for the transport source.
    #
    # Warning: Group is not updated by this command, to update the local view of the group, call group.reload.
    def update_security_group(group, rules)
      existing_rules = create_rules_from_group(group)
      add_security_group_rules(group,
                               rules - existing_rules)
      remove_security_group_rules(group,
                                  existing_rules - rules)
    end

    # Set up the given security groups.  Creates groups if needed, otherwise just updates the existing ones.
    # Operates in two passes as some security groups refer to others and these references can be
    # circular.
    # 
    # Warning: Does not remove other security groups. 
    def commission_security_groups(groups, environment, region)
      @region = region
      vpc_id = environment.override_attributes["clearwater"]["vpc"]["vpc_id"] rescue nil

      # Create the groups with no rules.
      groups.each do |group_name, rules|
        group_name = "#{environment}-#{group_name}"
        sg = find_or_create_group(group_name,
                                  vpc_id,
                                  "Security group for #{group_name} nodes")
      end

      # Now configure the rules.
      groups.each do |group_name, rules|
        group_name = "#{environment}-#{group_name}"
        sg = find_group(group_name, vpc_id)
        rules = fix_up_deployment_sg_names(rules, groups.keys, environment, vpc_id)
        update_security_group(sg, rules)
      end
    end

    # Remove the given security groups for a deployment.
    def delete_security_groups(groups, environment, region)
      @region = region
      vpc_id = environment.override_attributes["clearwater"]["vpc"]["vpc_id"] rescue nil

      # Since we may have circular dependencies in the groups, de-configure the rules before deleting the groups
      groups.each do |group_name, rules|
        group_name = "#{environment}-#{group_name}"
        sg = find_group(group_name, vpc_id)
        if sg
          Chef::Log.info "Deleting rules for #{group_name}"
          update_security_group(sg, [])
        end
      end

      groups.each do |group_name, rules|
        group_name = "#{environment}-#{group_name}"
        sg = find_group(group_name, vpc_id)
        if sg
          Chef::Log.info "Deleting #{group_name}"
          sg.destroy
        end
      end
    end

    # Extract the existing rules from a security group into the format that the other functions use.
    #
    # Warning: This only references the local view of the security group, if needed, call group.refresh before calling this.
    def create_rules_from_group(group)
      if group.ip_permissions
        group.ip_permissions.map do |perm|
          group_rules = perm["groups"].map do |src_group| 
            qualified_group = if group.owner_id == src_group["userId"]
                                src_group["groupId"]
                              else
                                {src_group["userId"] => src_group["groupId"]}
                              end
            { min: perm["fromPort"],
              max: perm["toPort"],
              ip_protocol: perm["ipProtocol"].to_sym,
              group: qualified_group }
          end
          ip_cidr_rules = perm["ipRanges"].map do |src_ip|
            { min: perm["fromPort"], 
              max: perm["toPort"],
              ip_protocol: perm["ipProtocol"].to_sym,
              cidr_ip: src_ip["cidrIp"] }
          end
          group_rules + ip_cidr_rules
        end.flatten
      else
        []
      end
    end

    # Corrects references to other security groups to include the deployment name
    def fix_up_deployment_sg_names(rules, known_groups, env, vpc_id)
      rules.map! do |rule|
        if rule[:group].is_a? String and known_groups.include? rule[:group]
          if vpc_id.nil?
            group = rule[:group]
          else
            group = "#{rule[:group]}-#{vpc_id}"
          end
          rule[:group] = translate_sg_to_id(env, group, @region)
        end
        rule
      end
      rules
    end

    def translate_sg_to_id(env, sg_name, region)
      @region = region
      sg = sg_api.get("#{env}-#{sg_name}")
      fail "Couldn't find security group #{env}-#{sg_name}" if sg.nil?
      sg.group_id
    end

    # The AWS Security Groups API object.
    def sg_api
      if @sg_api
        @sg_api
      else
        config = { aws_access_key_id: Chef::Config.knife[:aws_access_key_id],
                   aws_secret_access_key: Chef::Config.knife[:aws_secret_access_key],
                   region: @region }
        @sg_api = Fog::Compute::AWS.new(config).security_groups
      end
    end
  end
end
