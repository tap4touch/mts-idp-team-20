#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

TEAM="20"
EN="team-${TEAM}-en"
NN="team-${TEAM}-nn"
DN1="team-${TEAM}-00"
DN2="team-${TEAM}-01"
NODES=($EN $NN $DN1 $DN2)

HADOOP_VER="3.4.0"
HADOOP_HOME="/home/hadoop/hadoop-${HADOOP_VER}"
SSH_OPTS="-i $HOME/.ssh/team_internal -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q"

for NODE in "${NODES[@]}"; do
    if [ "$NODE" = "$EN" ]; then
        sudo cp config/mapred-site.xml config/yarn-site.xml ${HADOOP_HOME}/etc/hadoop/
        sudo chown hadoop:hadoop ${HADOOP_HOME}/etc/hadoop/mapred-site.xml ${HADOOP_HOME}/etc/hadoop/yarn-site.xml
        continue
    fi

    scp $SSH_OPTS config/mapred-site.xml team@$NODE:/tmp/
    scp $SSH_OPTS config/yarn-site.xml team@$NODE:/tmp/

    ssh $SSH_OPTS team@$NODE "
        set -e
        sudo mv /tmp/mapred-site.xml ${HADOOP_HOME}/etc/hadoop/
        sudo mv /tmp/yarn-site.xml ${HADOOP_HOME}/etc/hadoop/
        sudo chown hadoop:hadoop ${HADOOP_HOME}/etc/hadoop/mapred-site.xml
        sudo chown hadoop:hadoop ${HADOOP_HOME}/etc/hadoop/yarn-site.xml
    "
done

ssh $SSH_OPTS team@$NN "
    set -e
    sudo sed -i 's|team-20-nn:9868|0.0.0.0:9868|' ${HADOOP_HOME}/etc/hadoop/hdfs-site.xml
    sudo -H -u hadoop bash -lc '
        set -e
        source ~/.bashrc
        hdfs --daemon stop secondarynamenode
        hdfs --daemon start secondarynamenode
        start-yarn.sh
    '
"

ssh $SSH_OPTS team@$NN "
    sudo -H -u hadoop bash -lc '
        source ~/.bashrc
        mapred --daemon start historyserver
    '
"

ssh $SSH_OPTS team@$NN "
    sudo -H -u hadoop bash -lc '
        source ~/.bashrc
        yarn node -list
    '
"

echo "Установка завершена. YARN и JobHistory Server развернуты."
