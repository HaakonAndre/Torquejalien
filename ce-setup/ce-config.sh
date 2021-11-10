#!/bin/bash
set -e
[ x"$1" == x"" ] && echo "Usage: \$1<out> directory where to put CE/ Job Agent and Job Wrapper config" && exit 1
out="$(realpath $1)"
CE_CONFIG=$out/config/ComputingElement
replica_host="JCentral-dev"

function write_config() {
    
    [ -d CE_CONFIG ] && echo -e "\n Overwriting existing config in ${CE_CONFIG} \n"
    mkdir -p $CE_CONFIG/$1
    cat > $CE_CONFIG/$1/config.properties << EoF
ldap_server = $replica_host:8389
ldap_root = o=localhost,dc=localdomain
alien.users.basehomedir = /localhost/localdomain/user/

apiService = $replica_host:8098

trusted.certificates.location = $2/trusts
host.cert.priv.location = $2/globus/host/hostkey.pem
host.cert.pub.location = $2/globus/host/hostcert.pem
alice_close_site = JTestSite
EoF

    cat > $CE_CONFIG/$1/logging.properties << EoF
handlers= java.util.logging.FileHandler
java.util.logging.FileHandler.formatter = java.util.logging.SimpleFormatter
java.util.logging.FileHandler.limit = 1000000
java.util.logging.FileHandler.count = 4
java.util.logging.FileHandler.append = true
java.util.logging.FileHandler.pattern = $2/logs/jalien-ce-%g.log
.level = WARNING
lia.level = WARNING
lazyj.level = WARNING
apmon.level = WARNING
alien.level = FINEST
alien.monitoring.level = SEVERE
# tell LazyJ to use the same logging facilities
use_java_logger=true
EoF
}


write_config host $out
write_config docker /jalien-dev


#creates custom jdl with required params to override from generated jdl in HDCONDOR.java
cat > $CE_CONFIG/docker/custom-classad.jdl << EOF
use_x509userproxy = false
environment = "JALIEN_CM_AS_LDAP_PROXY='localhost.localdomain' JALIEN_HOST=$replica_host JALIEN_WSPORT=8097 ldap_server=$replica_host:8389 JALIEN_PORT=8098 ldap_root=o=localhost,dc=localdomain alien.users.basehomedir=/localhost/localdomain/user/ apiService=$replica_host:8098 trusted.certificates.location=/jalien-dev/globus/CA host.cert.priv.location=/jalien-dev/globus/host/hostkey.pem host.cert.pub.location=/jalien-dev/globus/host/hostcert.pem user.cert.priv.location=/jalien-dev/globus/user/userkey.pem user.cert.pub.location=/jalien-dev/globus/user/usercert.pem alice_close_site=JTestSite jAuthZ.priv.key.location=/jalien-dev/globus/authz/AuthZ_priv.pem jAuthZ.pub.key.location=/jalien-dev/globus/authz/AuthZ_pub.pem SE.priv.key.location=/jalien-dev/globus/SE/SE_priv.pem SE.pub.key.location=/jalien-dev/globus/SE/SE_pub.pem JALIEN_IGNORE_STORAGE=true"
EOF
cp $CE_CONFIG/docker/custom-classad.jdl $CE_CONFIG/host
echo "Computing Element Config done"