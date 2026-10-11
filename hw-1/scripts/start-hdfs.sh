#!/usr/bin/env bash
set -e

export HADOOP_HOME=/home/hadoop/hadoop-3.4.0
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64

if [ ! -f /tmp/hadoop-hadoop/dfs/name/current/VERSION ]; then
    "$HADOOP_HOME/bin/hdfs" namenode -format -nonInteractive
fi

"$HADOOP_HOME/sbin/start-dfs.sh"
