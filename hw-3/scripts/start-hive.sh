#!/bin/bash
set -e

source ~/.profile

wait_for_port() {
    local port=$1
    local service=$2
    local timeout=60
    local count=0
    echo "Waiting for $service on port $port..."
    while ! ss -ltn | grep -q ":$port " ; do
        sleep 1
        count=$((count+1))
        if [ $count -ge $timeout ]; then
            echo "ERROR: timeout waiting for $service (port $port)"
            exit 1
        fi
    done
    echo "$service is up."
}

if jps | grep -q "RunJar"; then
    echo "Hive processes already running. Use stop-hive.sh first."
    exit 1
fi

echo "Starting Hive Metastore"
nohup hive --service metastore > /tmp/hms.log 2>&1 &
wait_for_port 9083 "Metastore"

echo "Starting HiveServer2"
nohup hive --service hiveserver2 > /tmp/hs2.log 2>&1 &
wait_for_port 5433 "HiveServer2"

echo "Hive services started:"
jps | grep RunJar