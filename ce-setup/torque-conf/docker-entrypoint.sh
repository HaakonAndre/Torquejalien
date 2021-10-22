#!/bin/bash
set -e

if [ "$1" = "pbsServer" ]
then
    echo "$TORQUE_NODE np=1" > /var/spool/torque/server_priv/nodes
    qmgr -c < /etc/torque/torque.conf
    qmgr -c 'set server submit_hosts = $TORQUE_CLIENT'
fi

if [ "$1" = "pbsMom" ]
then

	printf "\$pbsserver $TORQUE_HOST \n\$logevent 255" > /var/spool/torque/mom_priv/config
	pbs_mom
    
fi




