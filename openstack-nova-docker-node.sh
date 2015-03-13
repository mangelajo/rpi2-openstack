#!/bin/sh
set -x
set -e

mkdir openstack
cd openstack/

#TODO: use tarballs instead, that's much faster
if [ ! -d nova ]; then
	git clone https://github.com/openstack/nova.git
	cd nova 
	git checkout stable/juno
	cd ..
fi

if [ ! -d neutron ]; then
	git clone https://github.com/openstack/neutron.git
	cd neutron/
	git checkout stable/juno
	cd ..
fi

if [ ! -d nova-docker ]; then
	git clone https://git.openstack.org/stackforge/nova-docker
	cd nova-docker/
	git checkout stable/juno
	cd ..
fi

apt-get update
apt-get -y install sudo python-pip python-dev libxml2-dev libxslt-dev libffi-dev \
 		   dkms module-init-tools
pip install pbr

cd neutron
python setup.py install -O2 
mv /usr/local/etc/neutron /etc
cd ..

cd nova
python setup.py install -O2 
cp -rfp etc/nova /etc
cd ..

cd nova-docker
python setup.py install -O2
cp -rfp etc/nova/* /etc/nova/
cd ..


pip install crudini


crudini --set /etc/neutron/neutron.conf DEFAULT verbose True
crudini --set /etc/neutron/neutron.conf DEFAULT debug False
crudini --set /etc/neutron/neutron.conf DEFAULT use_syslog False
mkdir /var/log/neutron
crudini --set /etc/neutron/neutron.conf DEFAULT log_dir /var/log/neutron
crudini --set /etc/neutron/neutron.conf DEFAULT core_plugin neutron.plugins.ml2.plugin.Ml2Plugin 
crudini --set /etc/neutron/neutron.conf DEFAULT send_events_interval 2
crudini --set /etc/neutron/neutron.conf DEFAULT kombu_reconnect_delay 1.0
crudini --set /etc/neutron/neutron.conf DEFAULT rabbit_hosts 192.168.1.48:5672
crudini --set /etc/neutron/neutron.conf DEFAULT rabbit_use_ssl False
crudini --set /etc/neutron/neutron.conf DEFAULT rabbit_userid amqp_user
crudini --set /etc/neutron/neutron.conf DEFAULT rabbit_password 1122334455
crudini --set /etc/neutron/neutron.conf DEFAULT rabbit_virtual_host /
crudini --set /etc/neutron/neutron.conf DEFAULT rabbit_ha_queues False
crudini --set /etc/neutron/neutron.conf DEFAULT rpc_backend neutron.openstack.common.rpc.impl_kombu
crudini --set /etc/neutron/neutron.conf DEFAULT control_exchange neutron

crudini --set /etc/neutron/neutron.conf agent root_helper ""
#neutron client stuff

crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_host 192.168.1.48 
crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_port 35357
crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_protocol http
crudini --set /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name services
crudini --set /etc/neutron/neutron.conf keystone_authtoken admin_user neutron
crudini --set /etc/neutron/neutron.conf keystone_authtoken admin_password c39751b7c416476b
crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://192.168.1.48:5000/

OVS=/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini

eth0ip=$(ip addr | grep inet | grep eth0 | awk -F" " '{print $2}' | sed -e 's/\/.*$//')

crudini --set $OVS ovs integration_bridge br-int
crudini --set $OVS agent polling_interval 2
crudini --set $OVS agent l2_population False
crudini --set $OVS agent arp_responder False
crudini --set $OVS securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

TUNNELING=true

if $TUNNELING; then
	crudini --set $OVS ovs enable_tunneling True 
	crudini --set $OVS agent tunnel_types gre
	crudini --set $OVS ovs network_vlan_ranges "" 
	crudini --set $OVS ovs bridge_mappings "" 
	crudini --set $OVS ovs tunnel_bridge br-tun
	crudini --set $OVS ovs local_ip $eth0ip
	crudini --set $OVS ovs tenant_network_type gre 
	crudini --set $OVS ovs use_veth_interconnection True
	ovs-vsctl del-br br-eth0 || true
else
	crudini --set $OVS ovs enable_tunneling False 
	crudini --set $OVS agent tunnel_types ""
	crudini --set $OVS ovs tenant_network_type vlan
	crudini --set $OVS ovs network_vlan_ranges physnet1:1:4094
	crudini --set $OVS ovs bridge_mappings physnet1:br-eth0
	crudini --set $OVS ovs tunnel_bridge "" 
	crudini --set $OVS ovs local_ip ""
	crudini --set $OVS ovs use_veth_interconnection False 
	ovs-vsctl add-br br-eth0 || true
	ovs-vsctl add-port br-eth0 eth0:1
fi

#LB=/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini
#
#crudini --set $LB vxlan enable_vxlan True
#crudini --set $LB vxlan local_ip $eth0ip
#crudini --set $LB securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver



apt-get install -y openvswitch-common openvswitch-switch python-openvswitch bridge-utils ipset


