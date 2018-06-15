#!/bin/bash

set -e
set -x

export PGPASSWORD=mysecretpassword

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# ==========================================
# Restore sampled example data if it exists
# ==========================================
if [ -f $DIR/postgres_smtest_data.dump ]; then
    dropdb --host localhost -U postgres smtest
    createdb --host localhost -U postgres smtest
    psql --host localhost -U postgres smtest < $DIR/postgres_smtest_data.dump
    exit 0
fi

# ================================
# Downlaod and load example data
# ================================
# From http://postgresguide.com/setup/example.html#understanding-the-schema
if [ ! -f $DIR/postgres_test_data.dump ]; then
    curl -L -o $DIR/postgres_test_data.dump http://cl.ly/173L141n3402/download/example.dump
fi

dropdb --host localhost -U postgres test
createdb --host localhost -U postgres test
pg_restore --host localhost -U postgres --no-owner --dbname test $DIR/postgres_test_data.dump

# ========================
# Sample example data
# ========================
# https://github.com/mla/pg_sampl
dropdb --host localhost -U postgres smtest
createdb --host localhost -U postgres smtest
pg_sample --host localhost -U postgres test > $DIR/postgres_smtest_data.sql
psql --host localhost -U postgres smtest < $DIR/postgres_smtest_data.sql

# ==============================
# Dump sampled example data
# ==============================
pg_dump --host localhost -U postgres smtest > $DIR/postgres_smtest_data.dump
