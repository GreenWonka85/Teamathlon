#!/usr/bin/env bash
# Spielt das Teamathlon-Datenbankschema in ein laufendes Supabase ein.
# Bereits eingespielte Dateien werden übersprungen, der Aufruf ist also
# auch nach einem Update gefahrlos wiederholbar.
#
# Aufruf im Supabase-Verzeichnis (dort, wo docker-compose.yml liegt):
#   ~/teamathlon/server/scripts/apply-migrations.sh
set -euo pipefail

MIGRATIONS_DIR="$(cd "$(dirname "$0")/../supabase/migrations" && pwd)"

if [[ ! -f docker-compose.yml ]]; then
    echo "Bitte im Supabase-Verzeichnis ausführen (dort liegt docker-compose.yml)." >&2
    exit 1
fi

psql_db() {
    docker compose exec -T db psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q "$@"
}

psql_db -c "create schema if not exists teamathlon_internal;
            create table if not exists teamathlon_internal.migrations (
                name text primary key,
                applied_at timestamptz not null default now());"

for file in "$MIGRATIONS_DIR"/*.sql; do
    name="$(basename "$file")"
    applied="$(psql_db -tA -c "select 1 from teamathlon_internal.migrations where name = '$name'")"
    if [[ "$applied" == "1" ]]; then
        echo "Übersprungen: $name"
        continue
    fi
    echo "Spiele ein: $name"
    # Datei und Eintrag in einer Transaktion: bei einem Fehler bleibt nichts halb eingespielt.
    { echo "begin;"; cat "$file"; echo "insert into teamathlon_internal.migrations (name) values ('$name');"; echo "commit;"; } | psql_db
done
echo "Datenbankschema ist aktuell."
