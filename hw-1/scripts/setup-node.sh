#!/usr/bin/env bash
set -e

if [ -d /tmp/hadoop-hadoop/dfs ]; then
    echo "На узле уже есть данные HDFS. Этот скрипт предназначен для новой установки."
    exit 1
fi

apt update
apt upgrade -y
apt install -y openjdk-11-jdk-headless openssh-server curl ca-certificates
systemctl enable --now ssh

if ! id hadoop >/dev/null 2>&1; then
    useradd -m -s /bin/bash hadoop
fi

cd /home/hadoop
if [ ! -d hadoop-3.4.0 ]; then
    curl -fL https://archive.apache.org/dist/hadoop/common/hadoop-3.4.0/hadoop-3.4.0.tar.gz -o hadoop-3.4.0.tar.gz
    tar -xzf hadoop-3.4.0.tar.gz
    rm hadoop-3.4.0.tar.gz
fi

cp /home/team/hw-1/config/core-site.xml hadoop-3.4.0/etc/hadoop/
cp /home/team/hw-1/config/hdfs-site.xml hadoop-3.4.0/etc/hadoop/
cp /home/team/hw-1/config/hadoop-env.sh hadoop-3.4.0/etc/hadoop/
cp /home/team/hw-1/config/workers hadoop-3.4.0/etc/hadoop/
cp /home/team/hw-1/scripts/start-hdfs.sh /home/hadoop/

if ! grep -q '^export HADOOP_HOME=' /home/hadoop/.profile; then
    cat >> /home/hadoop/.profile <<'EOF'
export HADOOP_HOME=/home/hadoop/hadoop-3.4.0
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export PATH="$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin"
EOF
fi

mkdir -p /home/hadoop/.ssh
chmod 700 /home/hadoop/.ssh
chown -R hadoop:hadoop /home/hadoop

if [ ! -f /home/hadoop/.ssh/id_ed25519 ]; then
    sudo -u hadoop ssh-keygen -t ed25519 -N '' -f /home/hadoop/.ssh/id_ed25519
fi

ssh-keyscan -t ed25519 team-20-en team-20-nn team-20-00 team-20-01 >> /home/hadoop/.ssh/known_hosts
chown hadoop:hadoop /home/hadoop/.ssh/known_hosts
chmod 600 /home/hadoop/.ssh/known_hosts
