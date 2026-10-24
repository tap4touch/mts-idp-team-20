
# Домашнее задание №4 — Apache Spark on YARN

## Архитектура

Запуск Apache Spark 3.5.9 в режиме `cluster` под управлением YARN на кластере из предыдущих заданий.
Spark читает данные из HDFS и сохраняет результат в Parquet с партиционированием. Таблица для чтения через Hive регистрируется с помощью Beeline.

| Узел | Роль в HW-4 |
| --- | --- |
| team-20-en | Edge Node, Spark Client, Beeline |
| team-20-nn | NameNode, YARN ResourceManager |
| team-20-00 | DataNode, YARN NodeManager |
| team-20-01 | DataNode, YARN NodeManager |

**Требования:**
- Успешно развернутые и запущенные HDFS и YARN (HW-1,2).
- Успешно развернутый и запущенный Hive Metastore и HiveServer2 (HW-3).

## Файлы

`config/spark-env.sh` — переменные окружения для Spark (пути к Java и Hadoop конфига).
`config/spark-defaults.conf` — параметры YARN, памяти и путь к архиву с JAR-файлами Spark в HDFS.
`config/hive-site.xml` — адрес Hive Metastore.
`jobs/transform_orders.py` — PySpark-скрипт: чтение CSV, очистка, расчет выручки, агрегация и запись партиционированного Parquet.

`scripts/setup-spark.sh` — скачивание Spark 3.5.9, архивация JAR-файлов, загрузка архива в HDFS (`/apps/spark`), настройка конфигов.
`scripts/run-spark-job.sh` — загрузка тестовых CSV в HDFS, запуск `spark-submit` и регистрация таблицы в Hive.
`scripts/verify-hive.sh` — проверка доступности созданной Spark-таблицы через стандартный клиент `beeline`.

## Установка

### 1. Скопировать репозиторий на edge

```bash
scp -i *ВАШ ПУТЬ К SSH* -o IdentitiesOnly=yes -r hw-4 team@178.236.27.62:~/
ssh -i *ВАШ ПУТЬ К SSH* -o IdentitiesOnly=yes team@178.236.27.62
```

### 2. Запустить установку Spark

На edge под `team` запустить установку:

```bash
bash ~/hw-4/scripts/setup-spark.sh
```

Скрипт:
- скачивает `spark-3.5.9-bin-hadoop3.tgz`;
- создает ZIP-архив с JAR-файлами Spark;
- загружает архив в HDFS (`hdfs://team-20-nn:9000/apps/spark/spark-3.5.9-jars.zip`), чтобы YARN мог раздавать его контейнерам;
- копирует конфиги в `$SPARK_HOME/conf`.

После установки перейти под `hadoop`:

```bash
sudo -iu hadoop
```

## Запуск Spark Job

Убедитесь, что сервисы Hive (Metastore и HiveServer2) запущены (из HW-3).

На `team-20-en` под `hadoop`:

```bash
bash ~/hw-4/scripts/run-spark-job.sh
```

Скрипт:
1. Генерирует тестовые CSV-данные и загружает их в HDFS (`/demo/spark_hw/orders_raw`).
2. Создает базу данных `shop` в Hive Metastore.
3. Запускает `spark-submit` на YARN. PySpark читает CSV, применяет фильтрацию, расчет выручки и агрегацию, затем пишет Parquet с партиционированием по `dt`.
4. Регистрирует результат как таблицу `shop.revenue_by_category` через Beeline.

## Проверка через Hive

На `team-20-en` под `hadoop`:

```bash
bash ~/hw-4/scripts/verify-hive.sh
```

Скрипт подключается к HiveServer2 через `beeline` и выполняет:
- `SHOW TABLES;`
- `SHOW PARTITIONS revenue_by_category;`
- `SELECT * FROM revenue_by_category;`

Ожидаемый результат: успешный вывод агрегированных данных, что подтверждает совместное использование Metastore и HDFS между Spark и Hive.
