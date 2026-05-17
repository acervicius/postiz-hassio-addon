#!/usr/bin/with-contenv bashio
set -e

write_env() {
    local name="$1"
    local value="$2"
    printf '%s' "$value" > "/var/run/s6/container_environment/${name}"
}

bashio::log.info "Rendering Postiz environment from add-on options"

if ! bashio::config.has_value 'main_url'; then
    bashio::exit.nok "Option 'main_url' is required. Set it to the URL you will reach Postiz at."
fi
if ! bashio::config.has_value 'jwt_secret'; then
    bashio::exit.nok "Option 'jwt_secret' is required. Generate one with: openssl rand -hex 32"
fi

MAIN_URL=$(bashio::config 'main_url')
JWT_SECRET=$(bashio::config 'jwt_secret')

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
