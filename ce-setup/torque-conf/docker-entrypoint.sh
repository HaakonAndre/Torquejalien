#!/bin/bash
set -e

if [ "$1" = "pbsServer" ]
then
    echo $TORQUE_HOST > var/spool/torque/server_name
    pbs_server -f -t create
    trqauthd    
    echo "$TORQUE_NODE np=1" > /var/spool/torque/server_priv/nodes
    if [ -s /etc/torque/torque.conf ]
    then
    while read line || [[ -n $line ]]
    do
    	qmgr -c $line
    done </etc/torque/torque.conf
    fi
    qmgr -c 'set server submit_hosts = $TORQUE_CLIENT'
    qterm -t quick
    exec pbs_server 
fi

if [ "$1" = "pbsMom" ]
then

	printf "\$pbsserver $TORQUE_HOST \n\$logevent 255" > /var/spool/torque/mom_priv/config
	exec pbs_mom
    
fi

exec "$@"

