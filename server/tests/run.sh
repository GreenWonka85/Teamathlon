#!/usr/bin/env bash
# Testet das Datenbankschema gegen ein leeres PostgreSQL.
# Aufruf: DATABASE_URL=postgres://postgres:postgres@localhost:5432/postgres ./run.sh
set -euo pipefail
cd "$(dirname "$0")"
: "${DATABASE_URL:?DATABASE_URL setzen}"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -c 'drop database if exists teamathlon_test' -c 'create database teamathlon_test'
TEST_URL="${DATABASE_URL%/*}/teamathlon_test"
psql "$TEST_URL" -v ON_ERROR_STOP=1 -q -f supabase_stub.sql
for f in ../supabase/migrations/*.sql; do
    psql "$TEST_URL" -v ON_ERROR_STOP=1 -q -f "$f"
done
# Ergebnisse unterdrücken, Meldungen (ok: ...) erscheinen auf stderr.
psql "$TEST_URL" -v ON_ERROR_STOP=1 -q -f test_schema.sql >/dev/null
