#!/bin/bash
yum -y install curl.x86_64 bind-utils.x86_64 redhat-lsb.x86_64 bzip2.x86_64 https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
rpm --import http://linuxsoft.cern.ch/wlcg/RPM-GPG-KEY-wlcg
echo -e "\n\n\nrpm done"
yum -y install http://linuxsoft.cern.ch/wlcg/centos7/x86_64/wlcg-repo-1.0.0-1.el7.noarch.rpm iproute date net-tools
echo -e "\n\n\nfurther dependencies done"
yum -y install alicexrdplugins xrootd xrootd-server xrootd-client xrootd-client-devel xrootd-python
echo -e "\n\n\n alice + xrootd done"
yum -y install python3 cmake3 python3-devel
pip3 install wheel setuptools
echo -e "\n\n\n\npython done"
pip3 install alienpy
ln -s /usr/bin/cmake3 /usr/bin/cmake
mkdir /shared-volume
chown xrootd:xrootd /shared-volume
echo "root:root" | chpasswd
echo "xrootd:xrootd" | chpasswd
echo "finally done"
