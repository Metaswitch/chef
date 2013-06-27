Clearwater Chef
========

This repository is for Chef recipes for Clearwater. It is based off of the template provided by opscode here: https://github.com/opscode/chef-repo

Project Clearwater is an open-source IMS core, developed by [Metaswitch Networks](http://www.metaswitch.com) and released under the [GNU GPLv3](http://www.projectclearwater.org/download/license/). You can find more information about it on [our website](http://www.projectclearwater.org/) or [our wiki](https://github.com/Metaswitch/clearwater-docs/wiki).

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

Also, see the [knife cheatsheet](http://docs.opscode.com/_images/qr_knife_web.png)
