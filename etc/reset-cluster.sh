#!/usr/bin/env bash
# Запускать на team-20-en под team. Удаляет Hadoop и все данные HDFS.
set -e

if [ "$(hostname -s)" != "team-20-en" ] || [ "$(id -un)" != "team" ]; then
    echo "Запустите скрипт на team-20-en под пользователем team."
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

for host in "${nodes[@]}"; do
    echo "--- stopping on $host ---"
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

    if sudo -u hadoop test -x "$HADOOP_HOME/bin/hdfs"; then
        sudo -u hadoop env JAVA_HOME="$JAVA_HOME" "$HADOOP_HOME/bin/hdfs" --daemon stop secondarynamenode || true
        sudo -u hadoop env JAVA_HOME="$JAVA_HOME" "$HADOOP_HOME/bin/hdfs" --daemon stop namenode || true
        sudo -u hadoop env JAVA_HOME="$JAVA_HOME" "$HADOOP_HOME/bin/hdfs" --daemon stop datanode || true
    fi

    sudo loginctl terminate-user hadoop || true
fi
STOP
done

for host in "${nodes[@]}"; do
    echo "--- checking $host ---"
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
    echo "--- cleaning $host ---"
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

echo "Hadoop, пользователь hadoop и данные HDFS удалены на четырёх узлах."
echo "Теперь можно заново выполнить установку из hw-1, затем hw-2."
