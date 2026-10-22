#!/usr/bin/env bash
set -e

case "${1:-}" in
    hw3|hw2|hw1|zero) mode="$1" ;;
    *) echo "Использование: bash reset-cluster.sh hw3|hw2|hw1|zero" >&2; exit 2 ;;
esac

if [ "$(hostname -s)" != "team-20-en" ] || [ "$(id -un)" != "team" ]; then
    echo "Запустите скрипт на team-20-en под пользователем team." >&2
    exit 1
fi

nodes=(team-20-nn team-20-00 team-20-01 team-20-en)

on_node() {
    if [ "$1" = "team-20-en" ]; then
        bash -s
    else
        ssh -i ~/.ssh/team_internal -o IdentitiesOnly=yes "team@$1" 'bash -s'
    fi
}

if sudo pgrep -a -u hadoop -f 'org.apache.spark.deploy.SparkSubmit.*sales.py'; then
    echo "Дождитесь завершения run-spark.sh перед откатом." >&2
    exit 1
fi

if [ "$mode" = hw3 ] && sudo test -d /home/hadoop/hw-4; then
    sudo -iu hadoop bash <<'DROP_SPARK_TABLE'
set -e
beeline -u jdbc:hive2://localhost:5433 -n hadoop -p "" \
    -e 'DROP TABLE IF EXISTS sales_summary;' >/dev/null
DROP_SPARK_TABLE
fi

if [ "$mode" != zero ] && sudo test -d /home/hadoop/hw-4; then
    sudo -u hadoop env JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
        /home/hadoop/hadoop-3.4.0/bin/hdfs dfs -rm -r -f /user/hadoop/hw-4 >/dev/null
fi

sudo rm -rf /home/hadoop/spark-3.5.7-bin-hadoop3 /home/hadoop/hw-4

if [ "$mode" = hw3 ]; then
    exit 0
fi

on_node team-20-en <<'STOP_HIVE'
set -e
if sudo test -f /home/hadoop/hw-3/scripts/stop-hive.sh; then
    sudo -u hadoop bash /home/hadoop/hw-3/scripts/stop-hive.sh >/dev/null
fi
if sudo pgrep -a -f -u hadoop 'org.apache.hadoop.hive.metastore.HiveMetaStore|org.apache.hive.service.server.HiveServer2'; then
    echo "Остались процессы Hive. Очистка остановлена." >&2
    exit 1
fi
STOP_HIVE

if [ "$mode" != zero ]; then
    on_node team-20-en <<'REMOVE_HIVE_DATA'
set -e
if sudo test -d /home/hadoop/apache-hive-4.0.0-alpha-2-bin; then
    sudo -u hadoop env JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
        /home/hadoop/hadoop-3.4.0/bin/hdfs dfs -rm -r -f /user/hive/warehouse /tmp/hive-staging >/dev/null
fi
REMOVE_HIVE_DATA
fi

on_node team-20-en <<'REMOVE_HIVE'
set -e
if sudo test -f /home/hadoop/.profile; then
    sudo sed -i '/^export HIVE_HOME=/d; /^export HIVE_CONF_DIR=/d; /^export HIVE_AUX_JARS_PATH=/d; /^export PATH=.*HIVE_HOME/d' /home/hadoop/.profile
fi
sudo rm -rf /home/hadoop/apache-hive-4.0.0-alpha-2-bin /home/hadoop/hw-3
sudo rm -f /tmp/hms.log /tmp/hs2.log /tmp/hive-site.xml
REMOVE_HIVE

on_node team-20-01 <<'REMOVE_POSTGRES'
set -e
if test -f /home/team/hw-3/.metastore-installed; then
    sudo -u postgres psql -v ON_ERROR_STOP=1 -d postgres -c 'DROP DATABASE IF EXISTS metastore WITH (FORCE);' >/dev/null
    sudo -u postgres psql -v ON_ERROR_STOP=1 -d postgres -c 'DROP ROLE IF EXISTS hive;' >/dev/null
    sudo systemctl stop postgresql
    sudo rm /home/team/hw-3/.metastore-installed
fi
REMOVE_POSTGRES

if [ "$mode" = hw2 ]; then
    exit 0
fi

for host in "${nodes[@]}"; do
    on_node "$host" <<'STOP'
set -e
if id hadoop >/dev/null 2>&1; then
    HADOOP_HOME=/home/hadoop/hadoop-3.4.0
    JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64

    if sudo -u hadoop test -x "$HADOOP_HOME/bin/mapred"; then
        sudo -u hadoop env JAVA_HOME="$JAVA_HOME" "$HADOOP_HOME/bin/mapred" --daemon stop historyserver || true
    fi

    if sudo -u hadoop test -x "$HADOOP_HOME/bin/yarn"; then
        sudo -u hadoop env JAVA_HOME="$JAVA_HOME" "$HADOOP_HOME/bin/yarn" --daemon stop resourcemanager || true
        sudo -u hadoop env JAVA_HOME="$JAVA_HOME" "$HADOOP_HOME/bin/yarn" --daemon stop nodemanager || true
    fi

fi
STOP
done

if [ "$mode" = hw1 ]; then
    for host in "${nodes[@]}"; do
        on_node "$host" <<'CHECK_HDFS'
set -e
id hadoop >/dev/null
sudo test -x /home/hadoop/hadoop-3.4.0/bin/hdfs
if [ "$(hostname -s)" = team-20-nn ]; then
    test -f /home/team/hw-1/config/hdfs-site.xml
fi
CHECK_HDFS
    done

    for host in "${nodes[@]}"; do
        on_node "$host" <<'CHECK_YARN'
set -e
if sudo pgrep -a -f -u hadoop 'org.apache.hadoop.yarn.server.resourcemanager.ResourceManager|org.apache.hadoop.yarn.server.nodemanager.NodeManager|org.apache.hadoop.mapreduce.v2.hs.JobHistoryServer'; then
    echo "Остались процессы YARN или JobHistory Server. Очистка остановлена." >&2
    exit 1
fi
CHECK_YARN
    done

    for host in "${nodes[@]}"; do
        on_node "$host" <<'CLEAN_YARN'
set -e
sudo rm -f /home/hadoop/hadoop-3.4.0/etc/hadoop/yarn-site.xml /home/hadoop/hadoop-3.4.0/etc/hadoop/mapred-site.xml
CLEAN_YARN
    done

    on_node team-20-nn <<'RESTORE_HDFS'
set -e
HADOOP_HOME=/home/hadoop/hadoop-3.4.0
JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
sudo -u hadoop env JAVA_HOME="$JAVA_HOME" "$HADOOP_HOME/bin/hdfs" --daemon stop secondarynamenode
sudo cp /home/team/hw-1/config/hdfs-site.xml "$HADOOP_HOME/etc/hadoop/hdfs-site.xml"
sudo chown hadoop:hadoop "$HADOOP_HOME/etc/hadoop/hdfs-site.xml"
sudo -u hadoop env JAVA_HOME="$JAVA_HOME" "$HADOOP_HOME/bin/hdfs" --daemon start secondarynamenode
RESTORE_HDFS

    exit 0
fi

for host in "${nodes[@]}"; do
    on_node "$host" <<'STOP_HDFS'
set -e
if id hadoop >/dev/null 2>&1; then
    HADOOP_HOME=/home/hadoop/hadoop-3.4.0
    JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
    if sudo -u hadoop test -x "$HADOOP_HOME/bin/hdfs"; then
        sudo -u hadoop env JAVA_HOME="$JAVA_HOME" "$HADOOP_HOME/bin/hdfs" --daemon stop secondarynamenode || true
        sudo -u hadoop env JAVA_HOME="$JAVA_HOME" "$HADOOP_HOME/bin/hdfs" --daemon stop namenode || true
        sudo -u hadoop env JAVA_HOME="$JAVA_HOME" "$HADOOP_HOME/bin/hdfs" --daemon stop datanode || true
    fi
    sudo loginctl terminate-user hadoop 2>/dev/null || true
fi
STOP_HDFS
done

for host in "${nodes[@]}"; do
    on_node "$host" <<'CHECK'
set -e
if id hadoop >/dev/null 2>&1; then
    if [ "$(getent passwd hadoop | cut -d: -f6)" != "/home/hadoop" ]; then
        echo "У hadoop нестандартный домашний каталог. Очистка остановлена." >&2
        exit 1
    fi
    if sudo pgrep -a -u hadoop; then
        echo "Остались процессы hadoop. Остановите их и закройте сессии hadoop перед очисткой." >&2
        exit 1
    fi
fi
CHECK
done

for host in "${nodes[@]}"; do
    on_node "$host" <<'CLEAN'
set -e
if id hadoop >/dev/null 2>&1; then
    sudo userdel -r hadoop
fi
sudo rm -rf -- /home/hadoop /tmp/hadoop-hadoop /tmp/hsperfdata_hadoop
sudo rm -f -- /tmp/hadoop-hadoop-*.pid /tmp/yarn-hadoop-*.pid /tmp/mapred-hadoop-*.pid
sudo rm -f -- /tmp/mapred-site.xml /tmp/yarn-site.xml /home/team/hadoop-keys.pub
CLEAN
done
