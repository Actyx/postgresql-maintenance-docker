#!/bin/bash

# This script will backup one or more Postgres databases and upload the gzipped dumps to S3, as well as delete any old backups.

# Validate dependencies
deps="aws pg_dump gzip"
for dep in ${deps}; do
  if ! which ${dep} > /dev/null; then
    echo "${dep} is required for proper operation of this script - please install it." > /dev/stderr
    exit -1
  fi
done

# Validate needed environment variables are set
if [[ -z "${DATABASE_HOST}" || -z "${DATABASE_USER}" || -z "${PGPASSWORD}" || -z "${BACKUP_FOLDER_NAME}" || -z "${BACKUP_S3_BUCKET}" || -z "${BACKUP_DATABASES}" ]]; then
  cat <<EOF > /dev/stderr
Please set the following environment variables:

  DATABASE_HOST - Hostname/IP address of the Postgres server.
  DATABASE_USER - Username to log in to the Postgres server.
  PGPASSWORD - Postgres password.
  BACKUP_DATABASES - Space-separated list of databases to dump. If you wish to dump only specific tables, use database:table1,table2,table3
  BACKUP_S3_BUCKET - S3 bucket and folder to store the dumps.
  BACKUP_FOLDER_NAME - Folder within the S3 bucket to store the dumps.
  BACKUP_SLEEP_SECONDS - (optional) Seconds to sleep after doing the dump. Useful in conjunction with `restart: always`. If not provided, the script will exit immediately after doing the dump.
  BACKUP_CLEANUP_SECONDS - (optional) After doing the dump, the script will clean up any old dumps older than this. If not provided, no cleanup will be done.
  BACKUP_TMP - (optional) Temporary directory to store the dump `.gz` file for each dump. If not specified, it will use the current working directory.
EOF
  exit -1
fi

# Validate user has permissions for S3 bucket
if ! aws s3 ls s3://${BACKUP_S3_BUCKET}/; then
  "${BACKUP_S3_BUCKET} either does not exist, the user in ~/.aws/config or the AWS credentials in the environment does not have permission to access it, or an AWS CLI error has occured. See the error above for more information."
  exit -1
fi

# Get times for path-making
timestamp=`date +%m_%d_%Y_%H%M`

now=$(date +%Y-%m-%d_%H:%M:%S)

s3_path=s3://${BACKUP_S3_BUCKET}/${BACKUP_FOLDER_NAME}

# Dump database & upload to S3
for database in ${BACKUP_DATABASES}; do
  database_name=$(echo ${database} | cut -f1 -d:)

  if [[ -z "${BACKUP_TMP}" ]]; then
    dumpfile=${database_name}.gz
  else
    dumpfile=${BACKUP_TMP}/${database_name}.gz
  fi

  if [[ ${database} == *:* ]]; then
    tables=$(echo ${database} | cut -f2 -d: | sed 's/,/ -t /')
    echo "Dumping tables ${tables} in database ${database}" > /dev/stderr
    pg_dump -h ${DATABASE_HOST} -U ${DATABASE_USER} -t ${tables} -d ${database_name} | gzip > ${dumpfile}
  else
    echo "Dumping database ${database}" > /dev/stderr
    pg_dump -h ${DATABASE_HOST} -U ${DATABASE_USER} -d ${database_name} | gzip > ${dumpfile}
  fi
  echo "Uploading ${dumpfile} to ${s3_path}/${now}/${dumpfile}"
  aws s3 cp  --region eu-central-1 ${dumpfile} ${s3_path}/${now}/${dumpfile}
  rm ${dumpfile}
done

# Clean up the output of `aws ls` to only contain folder names
for folder in $(aws s3 ls ${s3_path}/); do
  if [[ ${folder} != "PRE" ]];then
    folder_list=${folder_list}" ${folder}"
  fi
done

if [[ -n "${BACKUP_CLEANUP_SECONDS}" ]]; then
  today_seconds=$(date +%s)
  cleanup_timestamp=$(($today_seconds - ${BACKUP_CLEANUP_SECONDS}))

  for folder in ${folder_list}; do
    folder_date_created=$(echo "$folder" | cut -f 2 -d " " | cut -f 1 -d "/" | grep -v PRE | sed 's/_/ /')
    folder_date_created_seconds=$(date -d "${folder_date_created}" +%s)

    # Test folder creation date
    if [[ ${folder_date_created_seconds} -lt ${cleanup_timestamp} ]];then
      echo "Removing old dump ${s3_path}/${folder}" > /dev/stderr
      aws s3 rm --recursive ${s3_path}/${folder}
    fi
done
fi

if [[ -n "${BACKUP_SLEEP_SECONDS}" ]]; then
  sleep ${BACKUP_SLEEP_SECONDS}
fi
