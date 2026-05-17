ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm
ARG POSTIZ_IMAGE=ghcr.io/gitroomhq/postiz-app:latest

FROM ${POSTIZ_IMAGE} AS postiz-src

FROM ${BUILD_FROM}

ARG BUILD_ARCH=amd64
ARG BUILD_VERSION=0.1.0
ARG TEMPORAL_CLI_VERSION=1.4.1
ARG PG_MAJOR=17

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg lsb-release \
        nginx \
        redis-server \
        jq \
        tini \
        procps \
        ; \
    install -d /usr/share/postgresql-common/pgdg; \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
        -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc; \
    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends "postgresql-${PG_MAJOR}" "postgresql-client-${PG_MAJOR}"; \
    rm -rf /var/lib/apt/lists/* /var/lib/postgresql/${PG_MAJOR}/main

RUN set -eux; \
    case "${BUILD_ARCH}" in \
        amd64)   tarch="amd64" ;; \
        aarch64) tarch="arm64" ;; \
        *) echo "Unsupported BUILD_ARCH: ${BUILD_ARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/temporalio/cli/releases/download/v${TEMPORAL_CLI_VERSION}/temporal_cli_${TEMPORAL_CLI_VERSION}_linux_${tarch}.tar.gz" \
        -o /tmp/temporal.tgz; \
    tar -xzf /tmp/temporal.tgz -C /usr/local/bin temporal; \
    chmod +x /usr/local/bin/temporal; \
    rm /tmp/temporal.tgz; \
    /usr/local/bin/temporal --version

COPY --from=postiz-src /app /usr/share/postiz
COPY --from=postiz-src /usr/local/bin/node /usr/local/bin/node
COPY --from=postiz-src /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=postiz-src /usr/local/include/node /usr/local/include/node
COPY --from=postiz-src /etc/nginx/nginx.conf /etc/nginx/nginx.conf

RUN set -eux; \
    ln -sf ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm; \
    ln -sf ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx; \
    ln -sf ../lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack; \
    ln -sf ../lib/node_modules/pnpm/bin/pnpm.cjs /usr/local/bin/pnpm; \
    ln -sf ../lib/node_modules/pnpm/bin/pnpx.cjs /usr/local/bin/pnpx; \
    ln -sf ../lib/node_modules/pm2/bin/pm2 /usr/local/bin/pm2; \
    ln -sf ../lib/node_modules/pm2/bin/pm2-runtime /usr/local/bin/pm2-runtime; \
    node --version; \
    pnpm --version; \
    pm2 --version

RUN set -eux; \
    if ! getent group www >/dev/null; then addgroup --system www; fi; \
    if ! id -u www >/dev/null 2>&1; then \
        adduser --system --ingroup www --home /www --shell /usr/sbin/nologin www; \
    fi; \
    mkdir -p /var/log/nginx /var/lib/nginx /run/nginx; \
    chown -R www:www /var/lib/nginx /run/nginx; \
    rm -rf /uploads; \
    ln -s /data/uploads /uploads

COPY rootfs/ /

RUN set -eux; \
    chmod +x /etc/cont-init.d/*.sh; \
    chmod +x /etc/services.d/postgres/run /etc/services.d/postgres/finish; \
    chmod +x /etc/services.d/redis/run; \
    chmod +x /etc/services.d/temporal/run; \
    chmod +x /etc/services.d/postiz/run; \
    chmod +x /usr/local/bin/wait-for-tcp.sh

LABEL \
    io.hass.name="Postiz" \
    io.hass.description="Postiz social media scheduler bundled with PostgreSQL, Redis, and Temporal" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    io.hass.arch="${BUILD_ARCH}" \
    org.opencontainers.image.source="https://github.com/acervicius/postiz-hassio-addon" \
    org.opencontainers.image.licenses="AGPL-3.0-or-later"
