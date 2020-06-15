# Docker container for Postgres maintenance

This container is derived from [actyx/docker-alpine-cron](https://hub.docker.com/actyx/docker-alpine-cron), which gives basic cron functionality. It adds the following:
 
 * The `postgresql-client` package, which contains all of the Postgres command-line utilities (`psql`, `pg_dump`, etc.)
 
 * The AWS CLI
 
 * The `/usr/bin/backup-pg-databases.sh` script, which backs up PostgreSQL databases to S3.
 
 * The `/usr/bin/psql-run.sh` script, for convenience when running `psql` commands. It receives 2 arguments: the database to connect to and the command to run.

## Environment variables

Database connection:

> `DATABASE_HOST` - Hostname/IP address of the Postgres server.
>
> `DATABASE_USER` - Username to log in to the Postgres server.
>
> `PGPASSWORD` - Postgres password.

 [actyx/docker-alpine-cron](https://github.com/r/Actyx/docker-alpine-cron):

> `CRON_STRINGS` - strings with cron jobs. Use "\n" for newline (Default: undefined)
>
> `CRON_TAIL` - if defined the cron log file will be sent to *stdout* by *tail*. Additionally, if set to the value *no_logfile*, no log file will be created and logging will be to *stdout* only. (Default: undefined)
>
> `CRON_CMD_OUTPUT_LOG` - if defined the output of the commands executed by cron will also be sent to *stdout*, otherwise they will be ignored (Default: undefined)

`backup-pg-databases.sh` (only needed if you add the script to `CRON_STRINGS`):

> `AWS_ACCESS_KEY_ID` - AWS credentials (key ID)
>
> `AWS_SECRET_ACCESS_KEY` - AWS credentials (key secret)
>
> `BACKUP_DATABASES` - Space-separated list of databases to dump. If you wish to dump only specific tables, use database:table1,table2,table3
>
> `BACKUP_S3_PATH `- S3 bucket and folder to store the dumps.
>
> `BACKUP_FOLDER_NAME` - Folder within the S3 bucket to store the dumps.
>
> `BACKUP_SLEEP_SECONDS` - (optional) Seconds to sleep after doing the dump. Useful in conjunction with `restart: always`. If not provided, the script will exit immediately after doing the dump.
>
> `BACKUP_CLEANUP_SECONDS` - (optional) After doing the dump, the script will clean up any old dumps older than this. If not provided, no cleanup will be done.
>
> `BACKUP_TMP` - (optional) Temporary directory to store the dump `.gz` file for each dump. If not specified, it will use the current working directory.

## Examples

Sample `docker-compose.yml` stanza:

```yaml
  postgres-maintenance:
    image: actyx/docker-alpine-cron:latest
    environment:
      - AWS_ACCESS_KEY_ID=TheAccessKey
      - AWS_SECRET_ACCESS_KEY=TheSecret
      - DATABASE_HOST=db
      - DATABASE_USER=postgres
      - PGPASSWORD=postgres
      - CRON_STRINGS=* 0,6,12,18 * * * backup-pg-databases.sh\n30 1 * * * psql-run.sh grafana "vacuum analyze;\n* 2 * * * psql-run.sh postgres "vacuum analyze;"
      - BACKUP_DATABASES=grafana postgres:customers
      - BACKUP_S3_BUCKET=TheS3Bucket
        # keep backups for 2 days
      - BACKUP_CLEANUP_SECONDS=172800
      - BACKUP_FOLDER_NAME=foo
      - CRON_TAIL=1
    restart: always
    depends_on:
      - db
```
