# Домашнее задание №2 - YARN

| Узел | Сервисы |
|---|---|
| team-20-en | Edge |
| team-20-nn | ResourceManager, NodeManager, JobHistoryServer |
| team-20-00 | NodeManager |
| team-20-01 | NodeManager |


## Файлы

- `config/yarn-site.xml` - настройки ResourceManager и NodeManager;
- `config/mapred-site.xml` - MapReduce поверх YARN, адреса JobHistory Server;
- `deploy-yarn.sh` - раскладка конфигов на все узлы, запуск YARN и JobHistory Server.

## Установка и запуск

На компьютере в Git Bash, из корня репозитория, передать папку на edge. Заменить `ВАШ ПУТЬ К SSH` на путь к своему SSH-ключу:

```bash
scp -i "ВАШ ПУТЬ К SSH" -o IdentitiesOnly=yes -r hw-2 team@178.236.27.62:~/
ssh -i "ВАШ ПУТЬ К SSH" -o IdentitiesOnly=yes team@178.236.27.62
```

На edge под `team` запустить:

```bash
bash ~/hw-2/deploy-yarn.sh
```

Скрипт копирует `yarn-site.xml` и `mapred-site.xml` в `/home/hadoop/hadoop-3.4.0/etc/hadoop/` на всех четырёх узлах, затем запускает ResourceManager и NodeManager через `start-yarn.sh` и отдельно JobHistory Server через `mapred --daemon start historyserver`.

Для доступа к интерфейсу SecondaryNameNode через edge скрипт меняет его HTTP-адрес на сервере с `team-20-nn:9868` на `0.0.0.0:9868` и перезапускает SecondaryNameNode.

ResourceManager работает на `team-20-nn`, порт RPC `8032`, веб-интерфейс `8088`. NodeManager запускается на трёх узлах из `workers`: `team-20-nn`, `team-20-00`, `team-20-01`. JobHistory Server слушает порт `19888`.

Остановка на NameNode под `hadoop`:

```bash
"$HADOOP_HOME/sbin/stop-yarn.sh"
mapred --daemon stop historyserver
```

## Проверка

Достаточно доступа через localhost:

```bash
ssh -i "ВАШ ПУТЬ К SSH" -o IdentitiesOnly=yes -N \
    -L 9870:10.20.0.11:9870 \
    -L 9868:10.20.0.11:9868 \
    -L 9864:10.20.0.11:9864 \
    -L 9865:10.20.0.12:9864 \
    -L 9866:10.20.0.13:9864 \
    -L 8088:10.20.0.11:8088 \
    -L 8042:10.20.0.11:8042 \
    -L 8043:10.20.0.12:8042 \
    -L 8044:10.20.0.13:8042 \
    -L 19888:10.20.0.11:19888 \
    team@178.236.27.62
```

Открыть в браузере:

- <http://localhost:9870> - NameNode UI. В разделе DataNodes три живых узла.
- <http://localhost:9868> - SecondaryNameNode UI.
- <http://localhost:9864> - DataNode UI на `team-20-nn`.
- <http://localhost:9865> - DataNode UI на `team-20-00`.
- <http://localhost:9866> - DataNode UI на `team-20-01`.
- <http://localhost:8088> - ResourceManager UI. В разделе Active Nodes должно быть три узла: `team-20-nn`, `team-20-00`, `team-20-01`.
- <http://localhost:8042> - NodeManager UI на `team-20-nn`.
- <http://localhost:8043> - NodeManager UI на `team-20-00`.
- <http://localhost:8044> - NodeManager UI на `team-20-01`.
- <http://localhost:19888> - JobHistory Server UI. Открывается страница истории задач.


Проверка логов на критические ошибки:

```bash
grep -RIn "FATAL" /home/hadoop/hadoop-3.4.0/logs/
```

Пустой вывод означает отсутствие строк с `FATAL`. При проблемах нужно также посмотреть сообщения `ERROR` и исключения в логах текущего запуска.
