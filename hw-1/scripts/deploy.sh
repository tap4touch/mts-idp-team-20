#!/usr/bin/env bash
set -e

cd /home/team/hw-1
sudo bash scripts/setup-node.sh

for node in team-20-nn team-20-00 team-20-01; do
    scp -i ~/.ssh/team_internal -o IdentitiesOnly=yes -r /home/team/hw-1 "team@$node:/home/team/"
    ssh -i ~/.ssh/team_internal -o IdentitiesOnly=yes "team@$node" \
        'sudo bash /home/team/hw-1/scripts/setup-node.sh'
done

sudo cat /home/hadoop/.ssh/id_ed25519.pub > /home/team/hadoop-keys.pub
for node in team-20-nn team-20-00 team-20-01; do
    ssh -i ~/.ssh/team_internal -o IdentitiesOnly=yes "team@$node" \
        'sudo cat /home/hadoop/.ssh/id_ed25519.pub' >> /home/team/hadoop-keys.pub
done

sudo cp /home/team/hadoop-keys.pub /home/hadoop/.ssh/authorized_keys
sudo chown hadoop:hadoop /home/hadoop/.ssh/authorized_keys
sudo chmod 600 /home/hadoop/.ssh/authorized_keys

for node in team-20-nn team-20-00 team-20-01; do
    scp -i ~/.ssh/team_internal -o IdentitiesOnly=yes /home/team/hadoop-keys.pub "team@$node:/home/team/"
    ssh -i ~/.ssh/team_internal -o IdentitiesOnly=yes "team@$node" '
        set -e
        sudo cp /home/team/hadoop-keys.pub /home/hadoop/.ssh/authorized_keys
        sudo chown hadoop:hadoop /home/hadoop/.ssh/authorized_keys
        sudo chmod 600 /home/hadoop/.ssh/authorized_keys
        rm /home/team/hadoop-keys.pub
    '
done

rm /home/team/hadoop-keys.pub
echo "Установка завершена. Запустите start-hdfs.sh на NameNode под hadoop."
