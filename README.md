Project Clearwater is backed by Metaswitch Networks.  We have discontinued active support for this project as of 1st December 2019.  The mailing list archive is available in GitHub.  All of the documentation and source code remains available for the community in GitHub.  Metaswitch’s Clearwater Core product, built on Project Clearwater, remains an active and successful commercial offering.  Please contact clearwater@metaswitch.com for more information.

Clearwater Chef
========

This repository is for Chef recipes for Clearwater. It is based off of the template provided by opscode here: https://github.com/opscode/chef-repo

For instructions on how to use Chef with Clearwater, see:

* [Installing a Chef workstation](http://clearwater.readthedocs.org/en/stable/Installing_a_Chef_workstation.html)
* [Installing a Chef server](http://clearwater.readthedocs.org/en/stable/Installing_a_Chef_server.html)
* [Creating a deployment environment](http://clearwater.readthedocs.org/en/stable/Creating_a_deployment_environment.html)
* [Creating a deployment with Chef](http://clearwater.readthedocs.org/en/stable/Creating_a_deployment_with_Chef.html)

The recommended workflow is to keep all Chef configuration under version control, and to update the Chef server from
this configuration.

Updating the Chef server
========================

Knife provides commands for updating the config on the Chef server. Typically you'll be updating the following:

* Cookbooks - edit files in `cookbooks/` and upload with `knife cookbook upload <name>`
* Environments - edit files in `environments/` and upload with `knife environment from file environments/<name>.rb`
* Roles - edit files in `roles/` and upload with `knife role from file roles/<name>.rb`

For details on more knife commands check out [our documentation](https://github.com/Metaswitch/chef/blob/master/docs/knife_commands.md), run `knife --help` and consult the [chef documentation](http://docs.opscode.com/knife.html)

Also, see the [knife cheatsheet](http://docs.opscode.com/_images/qr_knife_web.png)
