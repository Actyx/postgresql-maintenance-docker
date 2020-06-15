#!/bin/bash

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <database> <command>"
    exit 1
fi

database=$1
shift
cmd=$@

psql -U $DATABASE_USER -h $DATABASE_HOST -D $database -c "$cmd"

