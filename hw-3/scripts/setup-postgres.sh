#!/bin/bash
set -e

HW_DIR="$(cd "$(dirname "$0")/.." && pwd)"

sudo apt update
sudo apt install -y postgresql postgresql-client

PG_VERSION=$(pg_lsclusters -h | head -n 1 | awk '{print $1}')
PG_CONF_DIR="/etc/postgresql/${PG_VERSION}/main"

if [ -z "$PG_VERSION" ] || [ ! -d "$PG_CONF_DIR" ]; then
    echo "ERROR: PostgreSQL config dir not found"
    exit 1
fi

echo "Configuring PostgreSQL version $PG_VERSION..."

if ! grep -q "^listen_addresses = '\*'" "$PG_CONF_DIR/postgresql.conf"; then
    sudo sed -i "s/^#\?listen_addresses = .*/listen_addresses = '*'/" "$PG_CONF_DIR/postgresql.conf"
fi

sudo cp "$HW_DIR/config/pg_hba.conf" "$PG_CONF_DIR/pg_hba.conf"
sudo chown postgres:postgres "$PG_CONF_DIR/pg_hba.conf"

sudo systemctl restart postgresql
sudo systemctl enable postgresql

sudo -i -u postgres psql -v ON_ERROR_STOP=1 <<'SQL'
SELECT 'CREATE USER hive WITH PASSWORD ''hiveMegaPass''' WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'hive')\gexec
ALTER USER hive WITH PASSWORD 'hiveMegaPass';
SELECT 'CREATE DATABASE metastore OWNER hive' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'metastore')\gexec
GRANT ALL PRIVILEGES ON DATABASE metastore TO hive;
ALTER DATABASE metastore OWNER TO hive;
SQL

touch "$HW_DIR/.metastore-installed"
