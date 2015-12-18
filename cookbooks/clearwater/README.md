Description
===========

Recipes for setting up a Clearwater deployment

The general pattern is to have one recipe per Clearwater component. 
All components inherit from the clearwater-base role.
This sets up security settings, and applies local config to the node.

Requirements
============

External cookbooks:
- apt

Ruby version:
1.9.1 compatible

Usage
=====

To create a role for a component add the recipe for the component to the
run list, preceding it with the clearwater-base role, e.g.

    name "ellis"
    description "ellis role"
    run_list [
        "role[clearwater-base]",
        "recipe[clearwater::ellis]"
        ] 

Consider whether the component should raise alarms, or if it uses etcd;
In these cases add the alarms role and/or the clearwater-etcd role.
