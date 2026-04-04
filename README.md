# uServer DataMgr

Data management microservices stack based on [PostgreSQL](https://hub.docker.com/_/postgres) (permanent data), [Redis](https://hub.docker.com/_/redis) (ephemeral data), [Adminer](https://hub.docker.com/_/adminer/) (DB UI interface) and a custom implementation of [postgresql-backup-s3](https://github.com/itbm/postgresql-backup-s3) (periodic backups and restoration tool).

It's part of the [uServer](https://github.com/users/ferdn4ndo/projects/1) stack project.


### Prepare the environment

Copy the environment template files...

```
cp adminer/.env.template adminer/.env
cp backup/.env.template backup/.env
cp postgres/.env.template postgres/.env
``` 
...and edit them accordingly.

Set **`postgres/.env`** **`POSTGRES_USER`** and **`POSTGRES_PASSWORD`** to the database superuser you want created on **first** startup (empty `dbdata` volume). The [official PostgreSQL image](https://hub.docker.com/_/postgres) only reads these on initial cluster creation. If you deploy with the **uServer** orchestration repo, use the same name as **`USERVER_DB_USER`** and the same password as **`USERVER_DB_PASSWORD`** so services that run `psql -U "$USERVER_DB_USER"` can administer the instance. Set **`backup/.env`** **`POSTGRES_USER`** to that same superuser so backups authenticate correctly.

### Run the Application

```sh
docker-compose up --build
```

### Force a database backup to AWS S3

```sh
docker exec -it userver-databackup sh -c "/scripts/backup.sh"
```

### List database backups on AWS S3

```sh
docker exec -it userver-databackup sh -c "/scripts/restore.sh"
```

### Restore a database from AWS S3

```sh
docker exec -it userver-databackup sh -c "/scripts/backup.sh <backup-filename>"
```