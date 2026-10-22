#!/bin/bash
set -e

source ~/.profile

TMP_DIR="/tmp/hive-load-$(date +%s)"
mkdir -p "$TMP_DIR"

cat > "$TMP_DIR/sales_2024_01.csv" <<'CSV'
1,laptop,1200.50
2,mouse,25.00
3,keyboard,75.30
4,monitor,350.00
CSV

cat > "$TMP_DIR/sales_2024_02.csv" <<'CSV'
5,phone,899.99
6,tablet,420.00
7,headphones,150.00
CSV

cat > "$TMP_DIR/sales_2025_01.csv" <<'CSV'
8,ssd,120.00
9,ram,95.50
10,webcam,65.00
CSV

beeline -u jdbc:hive2://localhost:5433 -n hadoop -p "" -e "DROP TABLE IF EXISTS sales_staging;"

hdfs dfs -mkdir -p /tmp/hive-staging
hdfs dfs -put -f "$TMP_DIR"/*.csv /tmp/hive-staging/

beeline -u jdbc:hive2://localhost:5433 -n hadoop -p "" <<'SQL'
CREATE EXTERNAL TABLE sales_staging (
    id INT,
    product STRING,
    amount DOUBLE
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/tmp/hive-staging';

DROP TABLE IF EXISTS sales;
CREATE TABLE sales (
    id INT,
    product STRING,
    amount DOUBLE
)
PARTITIONED BY (year INT, month INT)
STORED AS ORC;

SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;
SET hive.exec.max.dynamic.partitions=2048;
SET hive.exec.max.dynamic.partitions.pernode=2048;

INSERT OVERWRITE TABLE sales PARTITION(year, month)
SELECT id, product, amount, 2024 AS year, 1 AS month FROM sales_staging WHERE input__file__name LIKE '%2024_01%'
UNION ALL
SELECT id, product, amount, 2024 AS year, 2 AS month FROM sales_staging WHERE input__file__name LIKE '%2024_02%'
UNION ALL
SELECT id, product, amount, 2025 AS year, 1 AS month FROM sales_staging WHERE input__file__name LIKE '%2025_01%';

SHOW PARTITIONS sales;

SELECT year, month, COUNT(*) AS rows_count, SUM(amount) AS total_amount
FROM sales
GROUP BY year, month
ORDER BY year, month;
SQL

rm -rf "$TMP_DIR"
echo "Partitioned data loaded successfully."