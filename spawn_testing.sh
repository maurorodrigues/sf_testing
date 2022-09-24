#!/usr/bin/env bash
set -e
instances=$1
remotehost=$2
remotehost2=$3
first_ip=$4
iface_prefix=$5

if [ -z $remotehost ]; then
	exit -1
fi
function setup_pod() {
	id=$1
	iface=$2
	addr=$3
	remote=$4
	echo "Preparing pod${id}"
	podman run --name pod${id} \
		   -e "remotehost=${remote}" \
		   -e "syncserver=${synccontainer_ip}" \
		   -e "TEST_SET=stream"\
		   --detach uperf

	ns=$(podman inspect pod${id}  --format  '{{ .State.Pid}}' )
	ip link set netns $ns dev ${iface}
	nsenter	-t ${ns} -n ip link set mtu 1450 up dev ${iface}
	nsenter -t ${ns} -n ip a add ${addr}/16 dev ${iface}
}

base_ip=$(echo $first_ip |awk -F. '{ print $1"."$2"."$3 }')
start_ip=$(echo $first_ip | awk -F. '{ print $4 }')

set -x
podman run --name syncserver -e instances=${instances} --detach sync-container
synccontainer_ip=$(podman inspect syncserver --format "{{.NetworkSettings.IPAddress}}")

if [ ! -z ${remotehost2} ]; then
	for instance in $(seq 1 $(echo $(($instances/2)))); do
		setup_pod $instance $iface_prefix${instance} ${base_ip}.${start_ip} ${remotehost}
		start_ip=$(($start_ip+1))
	done
	for instance in $(seq $(echo $(($instances/2 + 1))) $instances); do
		setup_pod $instance $iface_prefix${instance} ${base_ip}.${start_ip} ${remotehost2}
		start_ip=$(($start_ip+1))
	done
fi

