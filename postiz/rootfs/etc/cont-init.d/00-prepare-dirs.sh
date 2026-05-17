#!/usr/bin/with-contenv bashio
set -e

bashio::log.info "Preparing persistent directories under /data"

mkdir -p /data/postgres /data/redis /data/temporal /data/uploads
chown -R postgres:postgres /data/postgres
chown -R redis:redis /data/redis
chown -R www:www /data/uploads
chmod 700 /data/postgres

# /uploads -> /data/uploads was created in the image; nothing to do here
# beyond making sure the target exists with the right owner (done above).
