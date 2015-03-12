#!/bin/sh
set -x
set -e

mkdir openstack
cd openstack/

#TODO: use tarballs instead, that's much faster

git clone https://github.com/openstack/nova.git
git clone https://github.com/openstack/neutron.git
git clone https://git.openstack.org/stackforge/nova-docker
cd neutron/
git checkout stable/juno
cd ..
cd nova 
git checkout stable/juno
cd ..
cd nova-docker/
git checkout stable/juno
cd ..

apt-get update
apt-get -y install sudo python-pip python-dev libxml2-dev libxslt-dev libffi-dev
pip install pbr
apt-get install 
cd neutron
python setup.py install -O2 --prefix=/usr --exec-prefix=/usr
mv /usr/etc/neutron /etc
cd ..

cd nova
python setup.py install -O2 --prefix=/usr --exec-prefix=/usr
cp -rfp etc/nova /etc
cd ..

crudini --set /etc/neutron/neutron.conf agent root_helper ""

#TODO: lots of stuff!!


