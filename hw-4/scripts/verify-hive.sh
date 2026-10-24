#!/bin/bash
set -e

beeline -u jdbc:hive2://localhost:5433 -n hadoop -p "" <<'SQL'
USE shop;
SHOW TABLES;
SHOW PARTITIONS revenue_by_category;
SELECT * FROM revenue_by_category ORDER BY dt, category;
SQL