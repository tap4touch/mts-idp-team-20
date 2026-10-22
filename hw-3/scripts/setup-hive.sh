#!/bin/bash
set -e

HW_DIR="$(cd "$(dirname "$0")/.." && pwd)"

HIVE_VERSION="4.0.0-alpha-2"
HIVE_TAR="apache-hive-${HIVE_VERSION}-bin.tar.gz"
HIVE_URL="https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/${HIVE_TAR}"
JDBC_URL="https://jdbc.postgresql.org/download/postgresql-42.7.14.jar"

HADOOP_USER="hadoop"
HIVE_HOME="/home/${HADOOP_USER}/apache-hive-${HIVE_VERSION}-bin"

sudo apt update
sudo apt install -y wget

sudo install -o "$HADOOP_USER" -g "$HADOOP_USER" -m 644 \
    "$HW_DIR/config/hive-site.xml" /tmp/hive-site.xml
sudo install -d -o "$HADOOP_USER" -g "$HADOOP_USER" /home/hadoop/hw-3
sudo cp -r "$HW_DIR/scripts" /home/hadoop/hw-3/
sudo chown -R "$HADOOP_USER:$HADOOP_USER" /home/hadoop/hw-3

sudo -iu "$HADOOP_USER" bash <<EOF
set -e
cd ~
if [ ! -f "$HIVE_TAR" ]; then
    wget -q "$HIVE_URL"
fi
if [ ! -d "$HIVE_HOME" ]; then
    tar -zxf "$HIVE_TAR"
fi

cd "$HIVE_HOME/lib"
if [ ! -f "postgresql-42.7.14.jar" ]; then
    wget -q "$JDBC_URL"
fi

cp /tmp/hive-site.xml "$HIVE_HOME/conf/hive-site.xml"

if ! grep -q "HIVE_HOME" ~/.profile; then
    cat >> ~/.profile <<'PROFILE'

export HIVE_HOME=/home/hadoop/apache-hive-4.0.0-alpha-2-bin
export HIVE_CONF_DIR=\$HIVE_HOME/conf
export HIVE_AUX_JARS_PATH=\$HIVE_HOME/lib/*
export PATH=\$PATH:\$HIVE_HOME/bin
PROFILE
fi
source ~/.profile

hdfs dfs -mkdir -p /tmp /user/hive/warehouse
hdfs dfs -chmod g+w /user/hive/warehouse
hdfs dfs -chmod g+w /tmp
hdfs dfs -mkdir -p /tmp/hive-staging
hdfs dfs -chmod g+w /tmp/hive-staging
EOF
