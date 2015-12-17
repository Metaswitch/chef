Knife commands
==============

# Creating/Deleting a single box

To create a single box, run:

    knife box create <role> -E <env>

You can also optionally add:

* `--index <number>` - This sets the index of node to create. If this is set then the index will be appended to the node name, and the `node_idx` value will be set in `/etc/clearwater/local_config`
* `--image <name>` - This parameter is used when creating an AMI image, and gives the AMI image the passed in name
* `--standalone` - This parameter controls whether the box should have the `shared_config` role. This should be set if creating the first box in the environment.

Creating a single box is typically used when creating an [AMI](http://clearwater.readthedocs.org/en/stable/All_in_one_EC2_AMI_Installation/index.html), an [AIO node](http://clearwater.readthedocs.org/en/stable/All_in_one_OVF_Installation/index.html), or spinning up a single box for testing. To change the boxes in an existing deployment you should use the `deployment resize` command described below.

To delete a single box, run:

    knife box delete <box_name - typically <env>-<role>[-<index>]> -E <env>

# Modifying a deployment

To create or resize a deployment, run:

    knife deployment resize -E <env>

You can optionally add:

* `--<box-type>-count` - This controls how many of each box type is created. As the default, chef creates one each of a Bono, Sprout, Homer, Homestead and Ellis.
* `--apply-shared-config` - If this is set, the shared configuration will be updated on every box after the resize is complete. This is service impacting (as many services need to be restarted to pick up the new configuration), so it isn't run by default. A useful case for this option is when you're resizing your deployment to have Ralf nodes when it didn't previously.

As well as passing in parameters to the `deployment resize` command, you can also set options in the `override_attributes` section of the environment file. The available options are discussed [here](http://clearwater.readthedocs.org/en/stable/Creating_a_deployment_environment/index.html#creating-the-environment); the notable ones are:

* `"repo_servers" => [<"repo_server">]` - This controls what source the nodes downloads the Clearwater debian packages from
* `"num_gr_sites" => number of GR sites` - If this is set, the nodes will be created in multiple sites (to mimic a geographically redundant deployment). Nodes will be in "siteX" where X is the node's index modulo the specified number of sites. Deployments created using this method won't have a long latency between sites though.
* `"vpc" => { "vpc_id" => "<vpc ID>", "subnet_id" => "<subnet ID>" }` - If this is set, the nodes will be installed in the requested [VPC](https://aws.amazon.com/vpc/)
* `"memento_enabled" => "Y"` - If this is set, then [Memento](https://github.com/Metaswitch/memento) is installed on all Sprout nodes
* `"gemini_enabled" => "Y"` - If this is set, then [Gemini](https://github.com/Metaswitch/gemini) is installed on all Sprout nodes

To describe a deployment, run:

    knife deployment describe -E <env>

This prints out what clearwater packages are installed on each box in the deployment

To delete a deployment, run:

    knife deployment delete -E <env>

This will delete all the boxes in the environment (with the exception of any AIO/AMI boxes). It will also delete any DNS records relating to the deleted boxes. It won't delete the security groups associated with the environment. 

# Creating security groups

On EC2, boxes are created in [security groups](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-network-security.html). These control what boxes are allowed to talk to each other, and on what ports (e.g. in Clearwater Sprout nodes can contact Homestead nodes on port 8888 - see [here](http://clearwater.readthedocs.org/en/stable/Clearwater_IP_Port_Usage/index.html) for the full list). 

To create the security groups, run:

    knife security groups create -E <env>
 
This command must be run before creating any boxes (it's run automatically as part of `deployment resize`). 

To delete the security groups, run:

    knife security groups delete -E <env>

# Creating DNS records

Chef will create DNS records for the nodes. This is done as part of the `deployment resize` command described above, and it generates the necessary records for Clearwater - see [here](http://clearwater.readthedocs.org/en/stable/Clearwater_DNS_Usage/index.html#requirements) for details).

# Cacti

Project Clearwater is integrated with [Cacti](http://www.cacti.net/), an open source statistics and graphing solution. There are more details for setting up and using Cacti with a deployment [here](http://clearwater.readthedocs.org/en/stable/Cacti/index.html)

# Shared config update

To update the shared configuration on all nodes, run:

    knife shared config update -E <env>

This uploads the existing configuration from the first Sprout in the deployment (`/etc/clearwater/shared_configuration`, `/etc/clearwater/enum.json`, `/etc/clearwater/bgcf.json` and `/etc/clearwater/s-cscf.json`), then applies it on every node, restarting services as appropriate (so this is service impacting). 

# Troubleshooting

On all commands, you can add -V to print INFO level logs to the terminal (recommended), and -VV to print DEBUG logs to the terminal. When a box is created though the `deployment resize` command, the commands run on that box are logged to `<chef checkout>/logs/<environment>-<role>-<index>-bootstrap-<date>.log`.

Sometimes, creating a box fails with an authentication error. If you hit this, check that your certificates have been set up correctly - see instructions [here](http://clearwater.readthedocs.org/en/stable/Installing_a_Chef_workstation/index.html#configure-the-chef-workstation-machine).

Another reason is that there's already been a box created with the same name. You can distinguish boxes of the same type by using the `index` otion in the `box create` command. If the box with the same name no longer exists, but Chef still has a reference to it, then you'll need to delete the Chef references. You can do this by running:

    knife client delete <box name> -E <env>
    knife node delete <box name> -E <env>
