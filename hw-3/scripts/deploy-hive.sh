#!/bin/bash
set -e

SSH_OPTS="-i $HOME/.ssh/team_internal -o IdentitiesOnly=yes"
PG_NODE="team-20-01"
HW_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Deploy PostgreSQL on $PG_NODE"
scp $SSH_OPTS -r "$HW_DIR" team@"$PG_NODE":~/
ssh $SSH_OPTS team@"$PG_NODE" "bash ~/hw-3/scripts/setup-postgres.sh"

echo "Install PostgreSQL client on edge and test connection"
sudo apt update
sudo apt install -y postgresql-client
PGPASSWORD=hiveMegaPass psql -h "$PG_NODE" -U hive -d metastore -c "SELECT 1;" || {
    echo "ERROR: cannot connect to PostgreSQL from edge. Check pg_hba.conf and listen_addresses."
    exit 1
}

echo "Deploy Hive on edge"
bash "$HW_DIR/scripts/setup-hive.sh"

echo "Done"