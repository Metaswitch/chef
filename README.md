Clearwater Chef
========

This repository is for Chef recipes for Clearwater. It is based off of the template provided by opscode here: https://github.com/opscode/chef-repo

For instructions on how to use Chef with Clearwater, see:

* [Installing a Chef client](https://github.com/Metaswitch/clearwater-docs/wiki/Installing-a-Chef-client)
* [Installing a Chef server](https://github.com/Metaswitch/clearwater-docs/wiki/Installing-a-Chef-server)
* [Creating a deployment environment](https://github.com/Metaswitch/clearwater-docs/wiki/Creating-a-deployment-environment)
* [Creating a deployment with Chef](https://github.com/Metaswitch/clearwater-docs/wiki/Creating-a-deployment-with-Chef)

The recommended workflow is to keep all Chef configuration under version control, and to update the Chef server from
this configuration.

Updating the Chef server
========================

Knife provides commands for updating the config on the Chef server. Typically you'll be updating the following:

* Cookbooks - edit files in `cookbooks/` and upload with `knife cookbook upload <name>`
* Environments - edit files in `environments/` and upload with `knife environment from file environments/<name>.rb`
* Roles - edit files in `roles/` and upload with `knife role from file roles/<name>.rb`

For details on more knife commands run `knife --help` and consult the [documentation](http://docs.opscode.com/knife.html)

