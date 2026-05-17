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

mkdir -p "$SOCKET_DIR"
chown postgres:postgres "$SOCKET_DIR"

if [ ! -s "${PGDATA}/PG_VERSION" ]; then
    bashio::log.info "Initialising PostgreSQL ${PG_MAJOR} cluster at ${PGDATA}"
    # auth=trust everywhere is safe here: PostgreSQL listens on 127.0.0.1
    # inside the add-on's network namespace only, so the container boundary
    # is the security boundary. Using trust avoids the scram-sha-256 vs md5
    # mismatch between Postgres 17 defaults and the DSN we hand to Postiz.
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
    local role="$1"
    [ "$(psql_local "-tAc \"SELECT 1 FROM pg_roles WHERE rolname='${role}'\"")" = "1" ]
}

db_exists() {
    local db="$1"
    [ "$(psql_local "-tAc \"SELECT 1 FROM pg_database WHERE datname='${db}'\"")" = "1" ]
}

if ! role_exists "postiz-user"; then
    bashio::log.info "Creating role postiz-user"
    psql_local "-c \"CREATE ROLE \\\"postiz-user\\\" WITH LOGIN PASSWORD 'postiz-password' CREATEDB\""
fi

if ! db_exists "postiz-db-local"; then
    bashio::log.info "Creating database postiz-db-local owned by postiz-user"
    psql_local "-c \"CREATE DATABASE \\\"postiz-db-local\\\" OWNER \\\"postiz-user\\\"\""
fi

bashio::log.info "Stopping bootstrap PostgreSQL; supervised instance will start next"
su -s /bin/sh postgres -c "${PGBIN}/pg_ctl -D ${PGDATA} -m fast -w -t 60 stop"
