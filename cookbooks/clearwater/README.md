Description
===========

Recipes for setting up a Clearwater deployment

The general pattern is to have one recipe per Clearwater component. 
All components inherit from clearwater-infrastructure

Requirements
============

External cookbooks:
- apt

Ruby version:
1.9.1 compatible

Usage
=====

To create a role for a component add the recipe for the component to the
run list, preceding it with the clearwater-infrastructure role, e.g.

    name "ellis"
    description "ellis role"
    run_list [
        "role[clearwater-infrastructure]",
        "recipe[clearwater::ellis]"
        ] 
