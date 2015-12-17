Description
===========

Recipes for setting up a Clearwater deployment

The general pattern is to have one recipe per Clearwater component. 
All components apply local config and inherit from chef-base.
They do this by inheriting from clearwater-base.

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

Also consider whether the component should have the alarms role,
or the etcd role (which installs clearwater management).
