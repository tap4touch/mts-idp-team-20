# Домашнее задание №1 - HDFS

| Узел | Сервисы |
|---|---|
| team-20-en | Edge, клиент Hadoop |
| team-20-nn | NameNode, SecondaryNameNode, DataNode |
| team-20-00 | DataNode |
| team-20-01 | DataNode |

Используются Ubuntu-серверы. Вход на edge - под `team`, на внутренние узлы - через ключ `~/.ssh/team_internal`. У `team` есть sudo без пароля. На всех узлах нужен доступ в интернет для установки Java и скачивания Hadoop.

Скрипты предназначены для первоначальной установки без существующих данных HDFS. Работающий кластер перед этим нужно отдельно остановить и сохранить нужные данные. Установщик сам ничего не удаляет из существующего HDFS.

## Файлы

- `config/core-site.xml` - адрес NameNode: `hdfs://team-20-nn:9000`;
- `config/hdfs-site.xml` - репликация 3, адреса NameNode и SecondaryNameNode;
- `config/hadoop-env.sh` - путь к Java 11;
- `config/workers` - три узла с DataNode;
- `scripts/setup-node.sh` - установка Java и Hadoop, создание пользователя `hadoop`, копирование конфигов, создание SSH-ключа на одном узле;
- `scripts/deploy.sh` - вызывает установку на четырёх узлах и распространяет публичные ключи `hadoop`, чтобы между узлами можно было переходить по SSH;
- `scripts/start-hdfs.sh` - первоначальное форматирование NameNode и запуск HDFS.

Hadoop устанавливается в `/home/hadoop/hadoop-3.4.0`. Процессы работают от пользователя `hadoop`, который владеет этим каталогом. Приватные SSH-ключи остаются на серверах и в репозиторий не копируются.

## Установка

На компьютере в Git Bash, из корня репозитория:

```bash
scp -i *ВАШ ПУТЬ К SSH* -o IdentitiesOnly=yes -r hw-1 team@178.236.27.62:~/
ssh -i *ВАШ ПУТЬ К SSH* -o IdentitiesOnly=yes team@178.236.27.62
```

На edge под `team` один раз подключиться к внутренним узлам, чтобы подтвердить их SSH-ключи. После каждой команды вернётся имя соответствующего узла:

```bash
for node in team-20-nn team-20-00 team-20-01; do
    ssh -i ~/.ssh/team_internal -o IdentitiesOnly=yes "team@$node" hostname
done
```

На edge под `team` запустить установку:

```bash
bash ~/hw-1/scripts/deploy.sh
```

На каждом из четырёх узлов скрипт сначала обновляет список пакетов и установленные пакеты, затем устанавливает Java и остальные зависимости.

Далее скрипт устанавливает Hadoop, создаёт пользователя `hadoop`, копирует конфиги на все узлы и настраивает SSH между ними.

## Запуск

С edge под `team` перейти на NameNode, затем переключиться на `hadoop`:

```bash
ssh -i ~/.ssh/team_internal -o IdentitiesOnly=yes team@team-20-nn
sudo -iu hadoop
bash ~/start-hdfs.sh
```

При первом запуске скрипт форматирует новый NameNode, затем запускает HDFS.

Во всех узлах адрес NameNode задан как `team-20-nn:9000`. На NameNode `dfs.namenode.rpc-bind-host=0.0.0.0` позволяет принимать подключения на всех сетевых интерфейсах. Веб-интерфейс использует порт `9870`.

Остановка на NameNode под `hadoop`:

```bash
"$HADOOP_HOME/sbin/stop-dfs.sh"
```

Повторный запуск после остановки:

```bash
bash ~/start-hdfs.sh
```

## Проверка

На компьютере в отдельном терминале открыть SSH-туннель:

```bash
ssh -i *ВАШ ПУТЬ К SSH* -o IdentitiesOnly=yes -N -L 9870:10.20.0.11:9870 team@178.236.27.62
```

Открыть <http://localhost:9870>. На вкладке DataNodes должны быть три работающих DataNode: `team-20-nn`, `team-20-00`, `team-20-01`, без недоступных или деградировавших узлов. Терминал с туннелем оставить открытым.
