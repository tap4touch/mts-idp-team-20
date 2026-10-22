# Домашнее задание №3 — Apache Hive

## Архитектура

Развертывание Hive в многопользовательском режиме (standalone Metastore + HiveServer2).
PostgreSQL используется как внешнее хранилище метаданных (не embedded).

| Узел | Сервисы |
| --- | --- |
| team-20-en | Edge, клиент Hadoop, HiveServer2, Hive Metastore Service |
| team-20-nn | NameNode, SecondaryNameNode, DataNode |
| team-20-00 | DataNode |
| team-20-01 | DataNode, PostgreSQL (metastore) |

Используются Ubuntu-серверы. Вход на edge — под `team`, на внутренние узлы — через ключ `~/.ssh/team_internal`. У `team` есть sudo без пароля.

Предполагается, что HW-1 (HDFS) и HW-2 (YARN) уже развернуты и работают.

## Требования

- Java 11 на edge (`java -version`).
- Доступ в интернет к `archive.apache.org` и `jdbc.postgresql.org`.
- Работающий HDFS с возможностью создать директорию `/tmp`.
- Sudo без пароля на `team-20-01` и `team-20-en`.

## Порты

| Порт | Сервис |
| --- | --- |
| 5432 | PostgreSQL (metastore) |
| 9083 | Hive Metastore (thrift) |
| 5433 | HiveServer2 (thrift) |
| 10002 | HiveServer2 web UI |

## Файлы

`config/hive-site.xml` — конфигурация Hive: подключение к Metastore на edge, хранение метаданных в PostgreSQL, порт HiveServer2 (5433), отключение аутентификации.

`config/pg_hba.conf` — правила доступа к PostgreSQL: разрешает подключения пользователю `hive` к БД `metastore` со всех узлов внутренней подсети 10.20.0.0/24.

`scripts/deploy-hive.sh` — оркестратор: установка PostgreSQL на `team-20-01`, проверка подключения с edge, установка Hive на `team-20-en`.

`scripts/setup-postgres.sh` — установка PostgreSQL, настройка `listen_addresses`, копирование `pg_hba.conf`, создание БД `metastore` и пользователя `hive`.

`scripts/setup-hive.sh` — скачивание Apache Hive 4.0.0-alpha-2, JDBC-драйвер PostgreSQL, копирование `hive-site.xml`, создание каталога `/user/hive/warehouse` в HDFS.

`scripts/init-hive-schema.sh` — инициализация схемы метаданных в PostgreSQL через `schematool`.

`scripts/start-hive.sh` — запуск Metastore и HiveServer2 с ожиданием открытия портов.

`scripts/stop-hive.sh` — остановка сервисов Hive.

`scripts/load-partitioned-data.sh` — создание партиционированной таблицы `sales` (партиции по `year` и `month`) и загрузка тестовых данных.

## Установка

### 1. Скопировать репозиторий на edge

На локальном компьютере из корня репозитория:

```bash
scp -i ~/.ssh/mts_data_platforms -o IdentitiesOnly=yes -r hw-3 team@178.236.27.62:~/
ssh -i ~/.ssh/mts_data_platforms -o IdentitiesOnly=yes team@178.236.27.62
```

### 2. Запустить установку

На edge под `team`:

```bash
bash ~/hw-3/scripts/deploy-hive.sh
```

Скрипт последовательно:
- устанавливает и настраивает PostgreSQL на `team-20-01`;
- ставит `postgresql-client` на edge и проверяет подключение к БД;
- скачивает Hive 4.0.0-alpha-2 и JDBC-драйвер на `team-20-en`;
- создаёт каталог `/user/hive/warehouse` в HDFS.

### 3. Инициализировать схему метаданных

```bash
sudo -iu hadoop
bash ~/hw-3/scripts/init-hive-schema.sh
```

Команда создаёт системные таблицы Hive в PostgreSQL. Выполняется один раз при первой установке.

## Запуск

На `team-20-en` под пользователем `hadoop`:

```bash
bash ~/hw-3/scripts/start-hive.sh
```

Скрипт запускает Metastore, ждёт открытия порта 9083, затем запускает HiveServer2 и ждёт порта 5433. Логи: `/tmp/hms.log` и `/tmp/hs2.log`.

Проверка процессов:

```bash
jps
```

Ожидаемый вывод содержит два процесса `RunJar` (Metastore и HiveServer2).

## Загрузка данных в партиционированную таблицу

На `team-20-en` под `hadoop`:

```bash
bash ~/hw-3/scripts/load-partitioned-data.sh
```

Скрипт:
1. Кладёт тестовые CSV в HDFS.
2. Создаёт EXTERNAL staging-таблицу `sales_staging`.
3. Создаёт партиционированную таблицу `sales` (ORC).
4. Загружает данные через `INSERT OVERWRITE ... PARTITION`.

Ожидаемый вывод в конце: три партиции (`2024/1`, `2024/2`, `2025/1`) и количество строк по каждой.

## Проверка

### Beeline

На `team-20-en` под `hadoop`:

```bash
beeline -u jdbc:hive2://localhost:5433 -n hadoop -p ""
```

Примеры запросов:

```sql
SHOW DATABASES;
SHOW TABLES;
SHOW PARTITIONS sales;
SELECT year, month, COUNT(*) FROM sales GROUP BY year, month;
```

### Веб-интерфейс HiveServer2

На локальном компьютере открыть дополнительный SSH-туннель:

```bash
ssh -i ~/.ssh/mts_data_platforms -o IdentitiesOnly=yes -N -L 10002:127.0.0.1:10002 team@178.236.27.62
```

Открыть http://localhost:10002

### Остановка

На `team-20-en` под `hadoop`:

```bash
bash ~/hw-3/scripts/stop-hive.sh
```


