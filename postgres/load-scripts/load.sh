#!/bin/bash

# exit upon error
set -e

PG_DATA_DIR=${PG_DATA_DIR:-$(pwd)/../../../ldbc_snb_datagen/social_network/}

PG_LOAD_TO_DB=${PG_LOAD_TO_DB:-load} # possible values: 'load', 'skip'
PG_DB_NAME=${PG_DB_NAME:-ldbcsf1}
PG_USER=${PG_USER:-$USER}
PG_PORT=${PG_PORT:-5432}

PG_FORCE_REGENERATE=${PG_FORCE_REGENERATE:-no}
PG_CREATE_MESSAGE_FILE=${PG_CREATE_MESSAGE_FILE:-no} # possible values: 'no', 'create', 'sort_by_date'

# we regenerate PostgreSQL-specific CSV files for posts and comments, if either
#  - it doesn't exist
#  - the source CSV is newer
#  - we are forced to do so by environment variable PG_FORCE_REGENERATE=yes

if [ ! -f $PG_DATA_DIR/post_0_0-postgres.csv -o $PG_DATA_DIR/post_0_0.csv -nt $PG_DATA_DIR/post_0_0-postgres.csv -o "${PG_FORCE_REGENERATE}x" = "yesx" ]; then
  cat $PG_DATA_DIR/post_0_0.csv | \
    awk -F '|' '{ print $1"|"$2"|"$3"|"$4"|"$5"|"$6"|"$7"|"$8"|"$9"|"$11"|"$10"|"}' > \
    $PG_DATA_DIR/post_0_0-postgres.csv
fi
if [ ! -f $PG_DATA_DIR/comment_0_0-postgres.csv -o $PG_DATA_DIR/comment_0_0.csv -nt $PG_DATA_DIR/comment_0_0-postgres.csv -o "${PG_FORCE_REGENERATE}x" = "yesx" ]; then
  cat $PG_DATA_DIR/comment_0_0.csv | \
    awk -F '|' '{print $1"||"$2"|"$3"|"$4"||"$5"|"$6"|"$7"|"$8"||"$9 $10}' > \
    $PG_DATA_DIR/comment_0_0-postgres.csv
fi

if [ "${PG_CREATE_MESSAGE_FILE}x" != "nox" ]; then
  if [ ! -f $PG_DATA_DIR/message_0_0-postgres.csv -o $PG_DATA_DIR/post_0_0-postgres.csv -nt $PG_DATA_DIR/message_0_0-postgres.csv -o $PG_DATA_DIR/comment_0_0-postgres.csv -nt $PG_DATA_DIR/message_0_0-postgres.csv -o "${PG_FORCE_REGENERATE}x" = "yesx" ] ; then
    # create CSV file header
    head -n 1 $PG_DATA_DIR/post_0_0-postgres.csv | sed -e 's/$/replyOfPostreplyOfComment/' >$PG_DATA_DIR/message_0_0-postgres.csv

    if [ "${PG_CREATE_MESSAGE_FILE}x" = "sort_by_datex" ]; then
      sortExec='sort -t| -k3'
    else
      # we just pipe data untouched
      sortExec=cat
    fi

    cat <(tail -n +2 $PG_DATA_DIR/post_0_0-postgres.csv) <(tail -n +2 $PG_DATA_DIR/comment_0_0-postgres.csv) | $sortExec >>$PG_DATA_DIR/message_0_0-postgres.csv
  fi
fi

if [ "${PG_LOAD_TO_DB}x" = "loadx" ]; then
  /usr/bin/dropdb --if-exists $PG_DB_NAME -U $PG_USER -p $PG_PORT
  /usr/bin/createdb $PG_DB_NAME -U $PG_USER -p $PG_PORT --template template0 -l "C"
  /usr/bin/psql -d $PG_DB_NAME -U $PG_USER -p $PG_PORT -a -f schema.sql
  (cat snb-load.sql | sed "s|PATHVAR|$PG_DATA_DIR|g"; echo "\q\n") | /usr/bin/psql -d $PG_DB_NAME -U $PG_USER -p $PG_PORT
  /usr/bin/psql -d $PG_DB_NAME -U $PG_USER -p $PG_PORT -a -f schema_constraints.sql
fi
