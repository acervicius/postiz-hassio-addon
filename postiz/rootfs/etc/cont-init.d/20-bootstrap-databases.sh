#!/usr/bin/with-contenv bashio
set -e

if [ ! -f /run/postiz-config-validated ]; then
    bashio::log.error "10-render-env.sh did not complete; skipping database bootstrap so /data stays untouched."
    exit 1
fi

PG_MAJOR=17
PGBIN="/usr/lib/postgresql/${PG_MAJOR}/bin"
PGDATA="/data/postgres"
SOCKET_DIR="/tmp/pg-bootstrap-sock"
TEMPORAL_SCHEMA_BASE="/usr/share/temporal/schema/postgresql/v12"
TEMPORAL_SCHEMA_MARKER="/data/.temporal-schema-applied"

mkdir -p "$SOCKET_DIR"
chown postgres:postgres "$SOCKET_DIR"

if [ ! -s "${PGDATA}/PG_VERSION" ]; then
    bashio::log.info "Initialising PostgreSQL ${PG_MAJOR} cluster at ${PGDATA}"
    # auth=trust everywhere is safe here: PostgreSQL listens on 127.0.0.1
    # inside the add-on's network namespace only, so the container boundary
    # is the security boundary. Using trust avoids the scram-sha-256 vs md5
    # mismatch between Postgres 17 defaults and the DSNs we hand to Postiz
    # and Temporal.
    su -s /bin/sh postgres -c \
        "${PGBIN}/initdb -D ${PGDATA} --auth-local=trust --auth-host=trust --username=postgres --encoding=UTF8 --locale=C.UTF-8"
fi

bashio::log.info "Starting PostgreSQL temporarily to bootstrap roles and databases"
su -s /bin/sh postgres -c \
    "${PGBIN}/pg_ctl -D ${PGDATA} -l /tmp/pg-bootstrap.log -o \"-c listen_addresses=127.0.0.1 -c unix_socket_directories=${SOCKET_DIR}\" -w -t 60 start"

psql_local() {
    su -s /bin/sh postgres -c "psql -h ${SOCKET_DIR} -v ON_ERROR_STOP=1 $*"
}

role_exists() {
    [ "$(psql_local "-tAc \"SELECT 1 FROM pg_roles WHERE rolname='$1'\"")" = "1" ]
}

db_exists() {
    [ "$(psql_local "-tAc \"SELECT 1 FROM pg_database WHERE datname='$1'\"")" = "1" ]
}

if ! role_exists "postiz-user"; then
    bashio::log.info "Creating role postiz-user"
    psql_local "-c \"CREATE ROLE \\\"postiz-user\\\" WITH LOGIN PASSWORD 'postiz-password' CREATEDB\""
fi
if ! db_exists "postiz-db-local"; then
    bashio::log.info "Creating database postiz-db-local"
    psql_local "-c \"CREATE DATABASE \\\"postiz-db-local\\\" OWNER \\\"postiz-user\\\"\""
fi

if ! role_exists "temporal"; then
    bashio::log.info "Creating role temporal"
    psql_local "-c \"CREATE ROLE temporal WITH LOGIN PASSWORD 'temporal' CREATEDB\""
fi
if ! db_exists "temporal"; then
    bashio::log.info "Creating database temporal"
    psql_local "-c \"CREATE DATABASE temporal OWNER temporal\""
fi
if ! db_exists "temporal_visibility"; then
    bashio::log.info "Creating database temporal_visibility"
    psql_local "-c \"CREATE DATABASE temporal_visibility OWNER temporal\""
fi

# temporal-sql-tool is idempotent on setup-schema (re-running just no-ops if
# the schema_version table is present), but we still gate the whole step
# behind a marker so an init failure halfway through doesn't leave the DB in
# a partly-migrated state that we then can't easily recover from.
if [ ! -f "${TEMPORAL_SCHEMA_MARKER}" ]; then
    bashio::log.info "Applying Temporal SQL schemas to PostgreSQL"

    SQLT=/usr/local/bin/temporal-sql-tool
    "${SQLT}" --plugin postgres12 --endpoint 127.0.0.1 --port 5432 \
        --user temporal --password temporal \
        --database temporal setup-schema -v 0.0
    "${SQLT}" --plugin postgres12 --endpoint 127.0.0.1 --port 5432 \
        --user temporal --password temporal \
        --database temporal update-schema -d "${TEMPORAL_SCHEMA_BASE}/temporal/versioned"

    "${SQLT}" --plugin postgres12 --endpoint 127.0.0.1 --port 5432 \
        --user temporal --password temporal \
        --database temporal_visibility setup-schema -v 0.0
    "${SQLT}" --plugin postgres12 --endpoint 127.0.0.1 --port 5432 \
        --user temporal --password temporal \
        --database temporal_visibility update-schema -d "${TEMPORAL_SCHEMA_BASE}/visibility/versioned"

    touch "${TEMPORAL_SCHEMA_MARKER}"
    bashio::log.info "Temporal schemas applied"
fi

bashio::log.info "Stopping bootstrap PostgreSQL; supervised instance will start next"
su -s /bin/sh postgres -c "${PGBIN}/pg_ctl -D ${PGDATA} -m fast -w -t 60 stop"
