#!/bin/bash

ip=$1
name=$2
tmpl_name=$3

cd /usr/share/cacti/cli

# Get the template number from the name
tmpl=`./add_device.php --list-host-templates | grep $tmpl_name | cut -f1`

# Add the host, associating it with the appropriate template
./add_device.php --ip=$ip --description=$name --community=clearwater --template=$tmpl --avail=snmp

# Find the ID of this host
this_node=`./add_graphs.php --list-hosts | grep $name | cut -f1`

# Add an entry for this host to the graphs tree
./add_tree.php --type=node --node-type=host --host-id=$this_node --tree-id=1

# Add each graph for the host
for graph in `./add_graphs.php --list-graph-templates --host-template-id=$tmpl | grep -E "^[0-9]" |
  cut -f 1`
do
  ./add_graphs.php --host-id=$this_node --graph-type=cg --graph-template-id=$graph
done
 
