#!/bin/bash
set -e

source ~/.profile
HW_DIR="$(cd "$(dirname "$0")/.." && pwd)"

TMP_DIR="/tmp/spark-hw-$(date +%s)"
mkdir -p "$TMP_DIR"

cat > "$TMP_DIR/orders.csv" <<'CSV'
order_id,order_ts,customer_id,category,quantity,price,dt
1,2026-10-01 10:00:00,101,Electronics,2,500.00,2026-10-01
2,2026-10-01 11:30:00,102,Books,1,25.50,2026-10-01
3,2026-10-02 09:15:00,101,Electronics,1,1200.00,2026-10-02
4,2026-10-02 14:00:00,103,Clothing,3,45.00,2026-10-02
5,2026-10-03 16:45:00,104,Books,2,15.00,2026-10-03
bad_row,corrupt_data
CSV

hdfs dfs -mkdir -p /demo/spark_hw/orders_raw
hdfs dfs -put -f "$TMP_DIR/orders.csv" /demo/spark_hw/orders_raw/

beeline -u jdbc:hive2://localhost:5433 -n hadoop -p "" -e "CREATE DATABASE IF NOT EXISTS shop;"

spark-submit \
    --master yarn \
    --deploy-mode cluster \
    --executor-memory 1g \
    --executor-cores 1 \
    --num-executors 2 \
    "$HW_DIR/jobs/transform_orders.py"

beeline -u jdbc:hive2://localhost:5433 -n hadoop -p "" <<'SQL'
CREATE EXTERNAL TABLE IF NOT EXISTS shop.revenue_by_category (
    category STRING,
    total_orders BIGINT,
    total_revenue DOUBLE
)
PARTITIONED BY (dt STRING)
STORED AS PARQUET
LOCATION '/demo/spark_hw/revenue_by_category';
MSCK REPAIR TABLE shop.revenue_by_category;
SQL

rm -rf "$TMP_DIR"
