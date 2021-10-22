#!/bin/bash
set -e

[ x"$1" == x"" ] && echo "Please specify the target path" && exit 1

sql_home="$(realpath $1)"
my_cnf="${sql_home}/my.cnf"

sql_socket="${sql_home}/jalien-mysql.sock"

sql_pid_file="/tmp/jalien-mysql.pid"
logdir=${LOGS:-/tmp}
sql_log="${logdir}/jalien-mysql.log"

systemDB="alice_system"
dataDB="alice_data"
userDB="alice_users"

sql_port=3307
mysql_pass="pass"
VO_name=localhost
base_home_dir="/localhost/localdomain/user/"
act_base_home_dir="localhost/localdomain/user/"

jalien_setup="/jalien-setup"
sql_templates="$jalien_setup/bash-setup/templates/sql"

[[ -z $USER ]] && username=$(id -u -n) || username=$USER

my_cnf_content="[mysqld]\n
                sql_mode=\n
                user= ${username}\n
                datadir=${sql_home}/data\n
                port= ${sql_port}\n
                socket= ${sql_socket}\n\n

                [mysqld_safe]\n
                log-error=${sql_log}\n
                pid-file=${sql_pid_file}\n\n

                [client]\n
                port=${sql_port}\n
                user=${username}\n
                socket=${sql_socket}\n\n

                [mysqladmin]\n
                user=root\n
                port=${sql_port}\n
                socket=${sql_socket}\n\n

                [mysql]\n
                port=${sql_port}\n
                socket=${sql_socket}\n\n

                [mysql_install_db]\n
                user=${username}\n
                port=${sql_port}\n
                datadir=${sql_home}/data\n
                socket=${sql_socket}\n\n\n"


function die(){
    if [[ $? -ne 0 ]]; then {
        echo "$1"
        exit 1
    }
    fi
}

function mysql_apply() {
    mysql --verbose -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql
}
function initializeDB() {
    mkdir -p $(dirname $my_cnf)
    echo -e $my_cnf_content > $my_cnf
    mysqld --defaults-file=$my_cnf --initialize-insecure --datadir="${sql_home}/data"
}

function startDB(){
    mysqld_safe --defaults-file=$my_cnf &>/dev/null &
}

function fillDatabase(){
    cp $sql_templates/mysql_passwd.txt /tmp
    sed -i -e "s:sql_pass:${mysql_pass}:g" -e "s:dataDB:${dataDB}:g" -e "s:userDB:${userDB}:g" /tmp/mysql_passwd.txt
    mysql --verbose -u root -h 127.0.0.1 -P $sql_port -D mysql < /tmp/mysql_passwd.txt
}

function createCatalogueDB(){
    cp $sql_templates/createCatalogue.txt /tmp
    sed -i -e "s:catDB:${1}:g" /tmp/createCatalogue.txt
    mysql_apply < /tmp/createCatalogue.txt
}

function addToHOSTSTABLE(){
    cp $sql_templates/hostIndex.txt /tmp
    sed -i -e "s:dataDB:${dataDB}:g" -e "s:userDB:${userDB}:g" -e "s:hostIndex:${1}:g" -e "s~address~${2}~g" -e "s:db:${3}:g" /tmp/hostIndex.txt
    mysql_apply < /tmp/hostIndex.txt
}

function addToINDEXTABLE(){
    cp $sql_templates/addIndexTable.txt /tmp
    sed -i -e "s:dataDB:${dataDB}:g" -e "s:userDB:${userDB}:g" -e "s:hostIndex:${1}:g" -e "s:tableName:${2}:g" -e "s:lfn:${3}:g" /tmp/addIndexTable.txt
    mysql_apply < /tmp/addIndexTable.txt
}

function addToGUIDINDEXTABLE(){
    cp $sql_templates/addGUIDIndex.txt /tmp
    sed -i -e "s:dataDB:${dataDB}:g" -e "s:userDB:${userDB}:g" -e "s:indexId:${1}:g" -e "s:hostIndex:${2}:g" -e "s:tableName:${3}:g" -e "s:guidTime:${4}:g" -e "s:guid2Time2:${5}:g" /tmp/addGUIDIndex.txt
    mysql_apply < /tmp/addGUIDIndex.txt
}


function catalogueInitialDirectories(){
    addToGUIDINDEXTABLE 1 1 0
    addToINDEXTABLE 1 0 /
    addToINDEXTABLE 2 0 $base_home_dir
    addToHOSTSTABLE 1 "${VO_name}:${sql_port}" $dataDB
    addToHOSTSTABLE 2 "${VO_name}:${sql_port}" $userDB
    sql_cmd="USE ${dataDB};LOCK TABLES L0L WRITE;INSERT INTO L0L VALUES (0,'admin',0,'2011-10-06 17:07:26',NULL,NULL,NULL,'',0,NULL,0,NULL,'admin','d',NULL,NULL,'755');UNLOCK TABLES;"
    echo $sql_cmd | mysql -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql
    sql_cmd="select entryId from ${dataDB}.L0L where lfn = '';"
    parentDir=$(echo $sql_cmd | mysql -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql -s)
    local IFS="/"
    arr=$act_base_home_dir
    new_path=''
    echo "finished out of loop"
    for i in $arr
    do
        unset IFS
        new_path+="${i}/"
        echo $new_path
        sql_cmd="USE ${dataDB};LOCK TABLES L0L WRITE;INSERT INTO L0L VALUES (0,'admin',0,'2011-10-06 17:07:26',NULL,NULL,NULL,'${new_path}',0,NULL,0,${parentDir},'admin','d',NULL,NULL,'755');UNLOCK TABLES;"
        echo $sql_cmd
        echo $sql_cmd | mysql --verbose -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql
        sql_cmd="select entryId from ${dataDB}.L0L where lfn = '${new_path}';"
        parentDir=$(echo $sql_cmd | mysql -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql -s)
        echo "reached so far ${parentDir}"
    done
    echo $new_path
    sql_cmd="select entryId from ${dataDB}.L0L where lfn = '${new_path}';"
    parentDir=$(echo $sql_cmd | mysql -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql -s)
    sql_cmd="UNLOCK TABLES;USE ${userDB};LOCK TABLES L0L WRITE;INSERT INTO L0L VALUES (0,'admin',0,'2011-10-06 17:07:26',NULL,NULL,NULL,'',0,NULL,0,${parentDir},'admin','d',NULL,NULL,'755');UNLOCK TABLES;"
    echo $sql_cmd | mysql --verbose -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql
}

function userAddSubTable(){
    sql_cmd="select entryId from ${userDB}.L0L where lfn = '';"
    parentDir=$(echo $sql_cmd | mysql -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql -s)
    sub_string=$(echo $1 | cut -c1)
    sql_cmd="USE ${userDB}; LOCK TABLES L0L WRITE;INSERT INTO L0L VALUES (0,'admin',0,'2011-10-06 17:07:26',NULL,NULL,NULL,'${sub_string}/',0,NULL,0,${parentDir},'admin','d',NULL,NULL,'755');UNLOCK TABLES;"
    echo $sql_cmd | mysql --verbose -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql
    sql_cmd="select entryId from ${userDB}.L0L where lfn = '${sub_string}/';"
    parentDir=$(echo $sql_cmd | mysql -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql -s)
    sql_cmd="USE ${userDB};LOCK TABLES L0L WRITE;INSERT INTO L0L VALUES (0,'${1}',0,'2011-10-06 17:07:26',NULL,NULL,NULL,'$sub_string/${1}/',0,NULL,0,${parentDir},'admin','d',NULL,NULL,'755');UNLOCK TABLES;"
    echo $sql_cmd | mysql --verbose -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql
}

function userIndexTable(){
    sub_string=$(echo $1 | cut -c1)
    sql_cmd="select entryId from ${dataDB}.L0L where lfn = '${act_base_home_dir}';"
    parentDir=$(echo $sql_cmd | mysql -u root -h 127.0.0.1 -p$mysql_pass -P $sql_port -D mysql -s)
    cp $sql_templates/userindextable.txt /tmp
    sed -i -e "s:userDB:${userDB}:g" -e "s:username:${1}:g" -e "s:actuid:${2}:g" -e "s:parentDir:${parentDir}:g" /tmp/userindextable.txt
    mysql_apply < /tmp/userindextable.txt
}

function addUserToDB(){
    userIndexTable $1 $2
    userAddSubTable $1 $2
}

function addSEtoDB(){
    cp $sql_templates/addSE.txt /tmp
    sub_string=$(echo $4 | cut -d':' -f1)
    sed -i -e "s:dataDB:${dataDB}:g" -e "s:userDB:${userDB}:g" -e "s:VO_name:${VO_name}:g" -e "s:sub_string:${sub_string}:g" \
        -e "s:seName:${1}:g" -e "s:seNumber:${2}:g" -e "s:site:${3}:g" -e "s~iodeamon~${4}~g" \
        -e "s:storedir:${5}:g" -e "s:qos:${6}:g" -e "s:freespace:${7}:g" /tmp/addSE.txt
    mysql_apply < /tmp/addSE.txt
}


function addProcesses(){
    cp $sql_templates/processes.txt $sql_templates/status_codes.txt /tmp
    mysql_apply < /tmp/processes.txt
    for n in $(cat ${sql_templates}/status_codes.txt); do
        code=$(echo $n | cut -d "," -f 1)
        status=$(echo $n | cut -d "," -f 2)
        sql_cmd="insert into processes.QUEUE_STATUS values ($code, $status);"
        echo $sql_cmd | mysql_apply
    done
}

function main(){
    (
        set -e
        if [[ ! -z $1 && "$1" = "addUserToDB" ]]; then {
            addUserToDB $2 $3
        }
        elif [[ ! -z $1 && "$1" = "addSEtoDB" ]]; then {
            addSEtoDB $2 $3 $4 $5 $6 $7 $8
        }
        else {
            initializeDB
            startDB

            sleep 6

            fillDatabase
            createCatalogueDB $dataDB
            createCatalogueDB $userDB

            catalogueInitialDirectories
            #addUserToDB "admin" 1
            addUserToDB "jalien" 0
            #addUserToDB "jobagent" -2
            addSEtoDB "firstse" 1 "JTestSite" "${SE_HOST}:1094" "/tmp" "disk"
            #addSEtoDB "secondse" 2 "JTestSite" "${SE_HOST_NEW}:1094" "/second" "disk"
            addProcesses
            echo "Done DB init"
            touch /tmp/jalien_db_ready
        }
        fi
        exit 0

    )
    die "DB setup failed!"
}
[ -e /tmp/jalien_db_ready ] && startDB && exit || true
main $@
