#!/bin/bash
set -e

HW_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SPARK_VERSION="3.5.9"
SPARK_TAR="spark-${SPARK_VERSION}-bin-hadoop3.tgz"
SPARK_URL="https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/${SPARK_TAR}"
SPARK_HOME="/home/hadoop/spark-${SPARK_VERSION}-bin-hadoop3"
HADOOP_USER="hadoop"

sudo apt update
sudo apt install -y wget python3 zip
sudo mkdir -p /home/hadoop/hw-4
sudo cp -r "$HW_DIR"/. /home/hadoop/hw-4/
sudo chown -R "$HADOOP_USER:$HADOOP_USER" /home/hadoop/hw-4

sudo -iu "$HADOOP_USER" bash <<EOF
set -e
cd ~

if [ ! -f "$SPARK_TAR" ]; then
    wget -q "$SPARK_URL" -O "$SPARK_TAR.part"
    mv "$SPARK_TAR.part" "$SPARK_TAR"
fi

if [ ! -d "$SPARK_HOME" ]; then
    tar -zxf "$SPARK_TAR"
fi

cd "$SPARK_HOME/jars"
if [ ! -f "../spark-${SPARK_VERSION}-jars.zip" ]; then
    zip -q -r "../spark-${SPARK_VERSION}-jars.zip" .
fi
cd ..

hdfs dfs -mkdir -p /apps/spark
hdfs dfs -put -f "spark-${SPARK_VERSION}-jars.zip" /apps/spark/

mkdir -p conf
cp /home/hadoop/hw-4/config/spark-env.sh conf/
cp /home/hadoop/hw-4/config/spark-defaults.conf conf/
cp /home/hadoop/hw-4/config/hive-site.xml conf/

if ! grep -q "SPARK_HOME" ~/.profile; then
    cat >> ~/.profile <<'PROFILE'

export SPARK_HOME=$SPARK_HOME
export PATH=\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin
export PYSPARK_PYTHON=python3
PROFILE
fi
source ~/.profile
EOF
