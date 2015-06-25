# Amazon EC2 VPC Support

Amazon EC2 offers the ability to run your instances in a Virtual Private Cloud (VPC) which allows you to fully control the networking environment, IP allocation rules, routing and firewalls.  The Chef deployment scripts in this repository support deploying Project Clearwater into a VPC but, due to the potential complexities of configuring the netwroking rules for the VPC (especially if you are attempting to use the VPC to host multiple services in multiple subnets), the scripts require you to set some configuration up front.

## Preparing your VPC

### Vanilla Configuration

If you simply want to create a VPC dedicated to running Project Clearwater, isolated from other services in your EC2 environment (but still accessible from the wider internet), you should follow these instructions:

1. Log into your Amazon EC2 management console and navigate to the VPC Dashboard (https://console.aws.amazon.com/vpc/home)
1. Click "Your VPCs" in the right-hand navigation pane
1. Click "Create VPC", filling in the following answers into the pop-up:
    * Name - A name to describe the VPC (e.g. `clearwater-vpc`)
    * CIDR Block - `10.0.0.0/16`
    * Tenancy - `Default`
1. Right-click on the newly created VPC and select "Edit DNS Hostnames"
1. Chose "Yes" and click "Save"
1. Click "Subnets" in the right-hand navigation pane
1. Click "Create Subnet", filling in the following answers into the pop-up:
    * Name - A name for the subnet (e.g. `clearwater-subnet`)
    * VPC - The VPC you just created
    * Availability Zone - `No Preference`
    * CIDR Block - `10.0.0.0/16`
1. Right-click on the newly created subnet and select "Modify Auto-assign Public IP"
1. Check the boc and click "Save"
1. Click "Internet Gateways" in the right-hand navigation pane
1. Click "Create Internet Gateway", filling in the following answers into the pop-up:
    * Name - A name for the gateway (e.g. `clearwater-gateway`)
1. Right-click on the newly created gateway and select "Attach to VPC"
1. Chose the VPC you just created and click "Save"
1. Click "Route Tables" in the right-hand navigation pane
1. Locate the route table that is associated with your VPC
    * Optionally you might want to give this table a name to distinguish it in the dashboard
1. Click the "Routes" tab at the bottom of the screen.
1. Click "Edit"
1. Click "Add another route" and fill in:
    * Destination - `0.0.0.0/0`
    * Target - The gateway you just created
1. Click "Save"

### Specialized Configuration

If you have existing VPCs and subnets and want to deploy Clearwater into them (for example to allow Clearwater access to other devices in that subnet without having to route through the public internet), you will simply need to ensure that the following is true:

* The VPC has "DNS hostnames" turned on.
* The subnet has sufficient IP addresses available for your Clearwater deployment (minimum is 5).
* The subnet has an internet gateway and routing rules such that devices in the subnet can reach the Clearwater repository server.

## Updating your Chef environment

Regardless of whether you've used the vanilla configuration or a custom setup, you should have chosen a VPC and a subnet.  Using the EC2 console, determine the ID for each of these (e.g. `vpc-123456789` and `subnet-987654321`).  Update your chef environment file (`environments/<env>.rb`) to include

    override_attributes "clearwater" => {
      ...
      "vpc" => { "vpc_id" => "<vpc_id>", "subnet_id" => "<subnet_id>" },
      ...
    }

Then run `knife environment from file <env>.rb` to update the chef server.  Now, future deployments will be made into the given subnet in the given VPN.
