#!/bin/bash
[ x"$1" == x"" ] && echo "Usage: \$1<out> directory where to put testVO/config" && exit 1

out="$(realpath $1)"
[ -d $out/config ] && echo "config directory already exists" && exit 1
jcentral_config_dir=$out/config/JCentral
mkdir -p $jcentral_config_dir

cat > $jcentral_config_dir/config.properties << EoF
ldap_server = 127.0.0.1:8389
ldap_root = o=localhost,dc=localdomain
alien.users.basehomedir = /localhost/localdomain/user/

apiService = 0.0.0.0:8098

trusted.certificates.location = /jalien-dev/trusts
host.cert.priv.location = /jalien-dev/globus/host/hostkey.pem
host.cert.pub.location = /jalien-dev/globus/host/hostcert.pem
alice_close_site = JTestSite

jAuthZ.priv.key.location = /jalien-dev/globus/authz/AuthZ_priv.pem
jAuthZ.pub.key.location = /jalien-dev/globus/authz/AuthZ_pub.pem
SE.priv.key.location = /jalien-dev/globus/SE/SE_priv.pem
SE.pub.key.location = /jalien-dev/globus/SE/SE_pub.pem

ca.password =
EoF

cat > $jcentral_config_dir/logging.properties << EoF
handlers= java.util.logging.FileHandler
java.util.logging.FileHandler.formatter = java.util.logging.SimpleFormatter
java.util.logging.FileHandler.limit = 1000000
java.util.logging.FileHandler.count = 4
java.util.logging.FileHandler.append = true
java.util.logging.FileHandler.pattern = /jalien-dev/logs/jcentral-%g.log
.level = WARNING
lia.level = WARNING
lazyj.level = WARNING
apmon.level = WARNING
alien.level = FINEST
alien.monitoring.level = SEVERE
# tell LazyJ to use the same logging facilities
use_java_logger=true
EoF

function write_db_config() {
  filename=$1
  db_name=$2

  cat > $filename <<EoF
password=pass
driver=com.mysql.jdbc.Driver
host=127.0.0.1
port=3307
database=$2
user=root
useSSL=false
EoF
}
write_db_config $jcentral_config_dir/processes.properties processes
write_db_config $jcentral_config_dir/alice_data.properties alice_data
write_db_config $jcentral_config_dir/alice_users.properties alice_users

# TODO: this will cause problems
echo "password=pass" >> $jcentral_config_dir/ldap.config
echo "CreateConfig done"
