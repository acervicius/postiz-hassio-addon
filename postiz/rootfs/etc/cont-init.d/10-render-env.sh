#!/usr/bin/with-contenv bashio
set -e

write_env() {
    local name="$1"
    local value="$2"
    printf '%s' "$value" > "/var/run/s6/container_environment/${name}"
}

bashio::log.info "Rendering Postiz environment from add-on options"

# Auto-detect a sensible main_url from the Supervisor when the user leaves
# the option blank, then persist the result under /data so this only runs
# once per install. An explicit option always wins.
detect_main_url() {
    local internal_url host_port scheme_host hostname
    local sup="http://supervisor"
    local hdr="Authorization: Bearer ${SUPERVISOR_TOKEN:-}"

    host_port=$(curl -fsS -m 5 -H "${hdr}" "${sup}/addons/self/info" 2>/dev/null \
        | jq -r '.data.network["5000/tcp"] // empty' 2>/dev/null)
    [ -z "${host_port}" ] && host_port=4007

    internal_url=$(curl -fsS -m 5 -H "${hdr}" "${sup}/core/info" 2>/dev/null \
        | jq -r '.data.internal_url // empty' 2>/dev/null)
    if [ -n "${internal_url}" ]; then
        scheme_host=$(printf '%s' "${internal_url}" \
            | sed -E 's|^(https?://[^/:]+).*$|\1|')
        printf '%s:%s' "${scheme_host}" "${host_port}"
        return
    fi

    hostname=$(curl -fsS -m 5 -H "${hdr}" "${sup}/host/info" 2>/dev/null \
        | jq -r '.data.hostname // empty' 2>/dev/null)
    if [ -n "${hostname}" ]; then
        printf 'http://%s.local:%s' "${hostname}" "${host_port}"
        return
    fi

    printf 'http://homeassistant.local:%s' "${host_port}"
}

MAIN_URL=$(bashio::config 'main_url')
MAIN_URL_FILE="/data/.main_url"
if [ -z "${MAIN_URL}" ]; then
    if [ -s "${MAIN_URL_FILE}" ]; then
        MAIN_URL=$(cat "${MAIN_URL_FILE}")
        bashio::log.info "Using persisted main_url from ${MAIN_URL_FILE}: ${MAIN_URL}"
    else
        MAIN_URL=$(detect_main_url)
        printf '%s' "${MAIN_URL}" > "${MAIN_URL_FILE}"
        bashio::log.info "Auto-detected main_url=${MAIN_URL} and persisted to ${MAIN_URL_FILE}"
        bashio::log.info "Override by setting 'main_url' in the add-on options if you reach Postiz on a different hostname."
    fi
fi

# jwt_secret can be left blank in the add-on options: we then generate a
# 32-byte random value and persist it under /data so it survives add-on
# restarts and snapshots. Resetting it means wiping /data, which already
# requires re-bootstrapping the Postgres cluster, so the secret rotation
# happens at the right cadence.
JWT_SECRET=$(bashio::config 'jwt_secret')
JWT_FILE="/data/.jwt_secret"
if [ -z "${JWT_SECRET}" ]; then
    if [ -s "${JWT_FILE}" ]; then
        JWT_SECRET=$(cat "${JWT_FILE}")
        bashio::log.info "Using persisted jwt_secret from ${JWT_FILE}"
    else
        JWT_SECRET=$(openssl rand -hex 32)
        (umask 077 && printf '%s' "${JWT_SECRET}" > "${JWT_FILE}")
        bashio::log.info "Generated jwt_secret and persisted to ${JWT_FILE}"
    fi
fi

write_env MAIN_URL              "$MAIN_URL"
write_env FRONTEND_URL          "$MAIN_URL"
write_env NEXT_PUBLIC_BACKEND_URL "${MAIN_URL%/}/api"
write_env JWT_SECRET            "$JWT_SECRET"

write_env DATABASE_URL          "postgresql://postiz-user:postiz-password@127.0.0.1:5432/postiz-db-local"
write_env REDIS_URL             "redis://127.0.0.1:6379"
write_env BACKEND_INTERNAL_URL  "http://127.0.0.1:3000"
write_env TEMPORAL_ADDRESS      "127.0.0.1:7233"
write_env IS_GENERAL            "true"
write_env NX_ADD_PLUGINS        "false"

STORAGE_PROVIDER=$(bashio::config 'storage_provider')
write_env STORAGE_PROVIDER      "$STORAGE_PROVIDER"
write_env UPLOAD_DIRECTORY      "/uploads"
write_env NEXT_PUBLIC_UPLOAD_DIRECTORY "/uploads"

DISABLE_REGISTRATION=$(bashio::config 'disable_registration')
write_env DISABLE_REGISTRATION  "$DISABLE_REGISTRATION"

# Map of add-on option key -> Postiz env var name. Empty values are still
# exported so Postiz consistently sees the variable (its code branches on
# truthiness, not on presence).
mappings=(
    "facebook_app_id:FACEBOOK_APP_ID"
    "facebook_app_secret:FACEBOOK_APP_SECRET"
    "threads_app_id:THREADS_APP_ID"
    "threads_app_secret:THREADS_APP_SECRET"
    "x_url:X_URL"
    "x_api_key:X_API_KEY"
    "x_api_secret:X_API_SECRET"
    "linkedin_client_id:LINKEDIN_CLIENT_ID"
    "linkedin_client_secret:LINKEDIN_CLIENT_SECRET"
    "youtube_client_id:YOUTUBE_CLIENT_ID"
    "youtube_client_secret:YOUTUBE_CLIENT_SECRET"
    "reddit_client_id:REDDIT_CLIENT_ID"
    "reddit_client_secret:REDDIT_CLIENT_SECRET"
    "openai_api_key:OPENAI_API_KEY"
    "cloudflare_account_id:CLOUDFLARE_ACCOUNT_ID"
    "cloudflare_access_key:CLOUDFLARE_ACCESS_KEY"
    "cloudflare_secret_access_key:CLOUDFLARE_SECRET_ACCESS_KEY"
    "cloudflare_bucket_name:CLOUDFLARE_BUCKETNAME"
    "cloudflare_bucket_url:CLOUDFLARE_BUCKET_URL"
    "cloudflare_region:CLOUDFLARE_REGION"
)

for entry in "${mappings[@]}"; do
    opt="${entry%%:*}"
    env_var="${entry#*:}"
    value=$(bashio::config "${opt}" '')
    write_env "${env_var}" "${value}"
done

bashio::log.info "Environment rendered: MAIN_URL=${MAIN_URL}, STORAGE_PROVIDER=${STORAGE_PROVIDER}"

# Marker so 20-bootstrap-databases.sh can tell that config rendering
# succeeded. s6-overlay's legacy cont-init runs every script regardless of
# individual failures and only aggregates the result at the end, so without
# this gate a missing main_url would still trigger initdb against /data.
touch /run/postiz-config-validated
