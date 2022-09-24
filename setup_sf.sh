#!/usr/bin/env bash
set -e

pf=$1
totalports=$2
ovs_br=$3

pci_bus=""
pfnum=""
hexchars="0123456789ABCDEF"

function get_port_pci_bus(){
	port=$1
	pci_bus=$(ethtool -i $port |grep bus-info |cut -d" " -f2)
	return $?
}

function get_pfnum(){
	pf_name=$1
	pfnum=$(devlink port show $pf_name | cut -d" " -f9)
	return $?
}

get_port_pci_bus $pf 
get_pfnum $pf
devlink dev eswitch set pci/$pci_bus mode switchdev

for i in $(seq 1 $totalports); do
	mac_suffix=$( for i in {1..6} ; do echo -n ${hexchars:$(( $RANDOM % 16 )):1} ; done | sed -e 's/\(..\)/:\1/g' )
	new_sf_port=$(devlink port add pci/$pci_bus flavour pcisf pfnum $pfnum sfnum $i |head -n1  | cut -d":" -f1,2,3)
	devlink port function set $new_sf_port  hw_addr 00:00:00$mac_suffix
	sleep 1
	sf_netdev=$(devlink port show $new_sf_port | head -n1 | cut -d" " -f5)
	echo "sf ${sf_netdev} created!"
	ovs-vsctl --may-exist add-port $ovs_br $sf_netdev
	devlink port function set $new_sf_port  state active

	ip link set mtu 1450 dev $sf_netdev
done


systemctl restart  openvswitch.service


