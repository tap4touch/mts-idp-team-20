#!/bin/bash

echo "Stopping Hive services"

pkill -f "org.apache.hadoop.hive.metastore.HiveMetaStore" 2>/dev/null || true
pkill -f "org.apache.hive.service.server.HiveServer2" 2>/dev/null || true

sleep 3

pkill -9 -f "org.apache.hadoop.hive.metastore.HiveMetaStore" 2>/dev/null || true
pkill -9 -f "org.apache.hive.service.server.HiveServer2" 2>/dev/null || true

echo "Cleanup done"
jps | grep RunJar || echo "No RunJar processes found."