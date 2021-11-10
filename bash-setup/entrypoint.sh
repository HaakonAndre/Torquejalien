#!/bin/bash
set -e

export JALIEN_SETUP=/jalien-setup
export JALIEN_DEV=/jalien-dev
export LOGS=$JALIEN_DEV/logs
export PATH=$PATH:$JALIEN_SETUP/bash-setup

# NOTE: LDAP config still depends on ~/.j/testVO paths
target="/root/.j/testVO"
mkdir -p $target
CreateLDAP.sh $target/slapd/slapd.d &>>$LOGS/setup_log.txt &
tail --pid $! -f $LOGS/setup_log.txt

CreateDB.sh $target/sql &>>$LOGS/setup_log.txt &
tail --pid $! -f $LOGS/setup_log.txt

mkdir -p ~/.globus
cp $JALIEN_DEV/trusts/alien.p12 ~/.globus

JCENTRAL_CMD="java -cp $JALIEN_DEV/alien-cs.jar -Duserid=$(id -u) -DAliEnConfig=/jalien-dev/config/JCentral alien.JCentral $(pwd)"


ls $JALIEN_DEV/*.jar | entr -rcs "$JCENTRAL_CMD &>$LOGS/jcentral_stdout.txt" &
tail --pid $! -f $LOGS/jcentral_stdout.txt
