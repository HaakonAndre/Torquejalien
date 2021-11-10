# Fix systemd-resolved problem
yum update;

# setup MySQL
rpm -Uvh https://repo.mysql.com/mysql80-community-release-el7-3.noarch.rpm
sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/mysql-community.repo
yum --enablerepo=mysql80-community install -y mysql-community-server
systemctl start mysqld

# Install dependencies
yum install -y wget
export LC_ALL=C
yum install -y java-11-openjdk-devel python3 python3-pip git slapd openldap-clients openldap openldap-servers rsync vim tmux less cmake zlib1g-dev uuid uuid-dev libssl-dev 

wget https://download-ib01.fedoraproject.org/pub/epel/7/x86_64/Packages/e/entr-4.4-1.el7.x86_64.rpm
rpm -ivh entr-4.4-1.el7.x86_64.rpm
yum install entr

systemctl start slapd

# Install XRootD
wget https://xrootd.slac.stanford.edu/download/v4.12.1/xrootd-4.12.1.tar.gz
tar xvzf xrootd-4.12.1.tar.gz
mkdir /build && cd /build
cmake /xrootd-4.12.1 -DCMAKE_INSTALL_PREFIX=/usr -DENABLE_PERL=FALSE
make && make install
cd /

#Install TORQUE
yum update 
yum install -y  libtool openssl-devel libxml2-devel boost-devel gcc gcc-c++ make environment-modules tcl
git clone https://github.com/adaptivecomputing/torque.git  
cd torque
./autogen.sh
./configure
make && make install

