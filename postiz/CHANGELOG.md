# Changelog

## 0.3.3

- Step the upstream Postiz pin back further from `v2.21.6` to
  **`v2.21.0`**. v2.21.6 ships the same `TypeError: Cannot assign to
  read only property 'name'` in Turbopack-bundled frontend chunks
  as v2.21.7 - the regression has been in every patch of v2.21.x
  except `.0`. Confirmed by diffing the root `package.json` across
  tags: v2.21.0 carries `next: 14.2.35`, v2.21.1 onwards bumped to
  `next: 16.2.1` (and with it Turbopack as the default build
  bundler).
- v2.21.0 is the last Postiz release on Next.js 14; we lose ~6 patch
  versions of features but gain a working frontend.
- Database note: the Prisma schema in v2.21.0 may differ from v2.21.6
  that may have already been pushed to `/data/postgres` on earlier
  boots of this add-on. If the add-on fails to start with Prisma
  schema errors, wipe `/data` per the v0.3.0 upgrade notes and let
  v0.3.3 re-init fresh.

## 0.3.2

- Fix v0.3.1 build failure: `temporalio/server:1.28.1` ships only the
  `temporal-server` binary; `temporal-sql-tool` is not in that image.
  Switch the build stage to `temporalio/auto-setup:1.28.1`, which is
  what Postiz upstream uses in their own docker-compose and bundles
  both binaries plus the setup helpers. Schemas continue to be
  pulled from the source tag tarball.

## 0.3.1

- Fix v0.3.0 build failure: the temporalio/server:1.28.1 image does not
  expose schemas under `/etc/temporal/schema`, so the Dockerfile's
  `COPY --from=temporal-src /etc/temporal/schema ...` step erred with
  `"/etc/temporal/schema": not found`. Pull the schemas from the
  matching `temporalio/temporal` source tag tarball on GitHub instead
  - they are pure SQL files and the version matches the
  `temporal-server` binary we copy from the image. Build-time test
  asserts both `postgresql/v12/temporal/versioned/` and
  `postgresql/v12/visibility/versioned/` are present before the layer
  finishes.

## 0.3.0

Major architecture change. Temporal no longer runs in `start-dev` mode
with SQLite persistence; it now uses the same PostgreSQL instance that
already runs in the container, with dedicated `temporal` and
`temporal_visibility` databases owned by a `temporal` role. The CLI's
`server start-dev` was always going to bottleneck on SQLite under
Postiz's worker-burst startup, even with the WAL tuning from 0.2.3.

- `Dockerfile`: new build stage `FROM temporalio/server:1.28.1 AS
  temporal-src`; the `temporal-server`, `temporal-sql-tool` binaries
  and the canonical PostgreSQL v12 schemas are copied into the final
  image. The `temporal` CLI we already had is kept for namespace ops.
- `20-bootstrap-databases.sh`: creates the `temporal` role and both
  Temporal databases on first boot (idempotent, alongside the
  existing `postiz-user` / `postiz-db-local` creation), then runs
  `temporal-sql-tool setup-schema` + `update-schema` against each. A
  `/data/.temporal-schema-applied` marker file keeps re-runs no-op.
- `services.d/temporal/run`: replaces the `temporal server start-dev
  --db-filename ... --sqlite-pragma ...` invocation with
  `temporal-server --root /etc/temporal --env production start
  --service frontend --service history --service matching --service
  worker`, configured via the new
  `/etc/temporal/config/production.yaml`.
- `services.d/postiz/run`: after Temporal frontend answers
  `cluster health`, idempotently creates the `default` namespace
  (7-day retention). The dev-mode auto-create from `start-dev` does
  not happen with the production server, so Postiz would otherwise
  fail to enqueue workflows.
- `services.d/postgres/run`: tuning for consumer-grade storage.
  `synchronous_commit=off` (last few seconds of writes may be lost
  on hard power-loss, DB stays consistent), `checkpoint_timeout=15m`,
  `max_wal_size=2GB`, `checkpoint_completion_target=0.9`,
  `wal_buffers=16MB`, `shared_buffers=128MB`,
  `effective_cache_size=512MB`. The 68-second checkpoint stalls
  observed in v0.2.4 logs should drop to a few seconds, and Temporal
  should not lose grpc calls to PG checkpoint contention.

### Upgrade notes

The bootstrap script is purely additive over an existing v0.2.x
`/data/postgres` (new role + new databases are created next to the
existing `postiz-db-local`), so no wipe is *required*. The old
`/data/temporal/temporal.db` SQLite file from v0.2.x is no longer
read by anything; it can be left in place or deleted to reclaim
disk.

If you have been hitting odd state from earlier v0.2.x boots (the
in-progress account, partly-initialised tables, etc.) and want a
clean slate, stop the add-on in HA, then via the SSH & Web Terminal
add-on:

    rm -rf /usr/share/hassio/addons/data/04a391a1_postiz/*

Start the add-on again; first boot will re-run the full init.

## 0.2.5

- Pin the upstream Postiz image from `:latest` to `:v2.21.6` in
  `Dockerfile`. v2.21.7 (which `:latest` currently points to) ships
  frontend chunks built with Turbopack that strip the `uuid`
  library's defensive `try { i.name = e } catch {}` wrapper, causing
  an uncaught `TypeError: Cannot assign to read only property 'name'`
  at module evaluation time. The result is a permanent black page on
  `/launches` after sign-up, with no React tree mount. v2.21.6 is the
  previous patch, expected to share the same Prisma schema and not
  require any data migration.
- Pinning by tag rather than digest is deliberate: Postiz fixed a
  related cache-bust issue in `:v2.21.6-amd64` after the multi-arch
  manifest was published, but the multi-arch `v2.21.6` is the same
  application code.

## 0.2.4

- Mark the add-on as `stage: experimental`, so the Home Assistant
  Add-on Store renders the matching badge. This is honest signalling
  while v0.2.x still has known rough edges (Temporal under
  SQLite tuning, no Ingress, single-container database lifecycle).
  We will drop back to `stable` once Postgres-backed Temporal lands
  in v0.3.0 and a real install has run for a week without issues.

## 0.2.3

- Temporal's embedded SQLite was deadlocking under the burst of work
  Postiz's orchestrator throws at startup (14 workflow bundles + 14
  worker registrations against one DB file). gRPC calls to
  `DescribeNamespace` and `GetTimerTasks` were timing out at 30s, the
  orchestrator was crash-looping with `Namespace default was not
  found`, and the backend never finished its Temporal handshake -
  which is why nginx kept getting `ECONNREFUSED` on `/api/*`.
- Pass SQLite tuning pragmas to `temporal server start-dev`:
  `journal_mode=WAL`, `synchronous=NORMAL`, `temp_store=MEMORY`,
  `cache_size=-65536`. WAL lets the four Temporal services
  (frontend/history/matching/worker) read concurrently with writers
  instead of serialising on a single lock; NORMAL drops the
  per-transaction `fsync` while staying crash-safe; the in-memory
  temp store and 64 MB page cache remove two more disk hits. Standard
  SQLite-under-concurrent-load tuning.
- If this is not enough on slower storage, v0.3.0 will switch
  Temporal to a Postgres backend using the existing add-on Postgres,
  per the architecture we originally discussed.

## 0.2.2

- `main_url` is now optional. If you leave it blank, the add-on asks the
  Supervisor for HA's `internal_url` and the host port assigned to the
  add-on's `5000/tcp`, builds a default like `http://<host>:<port>`,
  and persists it to `/data/.main_url` so the same URL is reused on
  every subsequent boot. Setting `main_url` explicitly still wins -
  use it when you reach Postiz on an external domain, a non-default
  HA hostname, or HTTPS.
- The previous default `http://homeassistant.local:4007` was wrong for
  anyone whose HA install uses a different hostname; the field now
  starts empty.
- `config.yaml`: enable `hassio_api: true` so the add-on can read
  `/core/info`, `/host/info`, and `/addons/self/info` for the
  auto-detect.
- `jwt_secret` schema relaxed to optional (the v0.2.1 auto-generator
  already handled the empty case but the schema still marked it
  required, which would have made future option saves fail validation
  with `jwt_secret` blank).

## 0.2.1

- `jwt_secret` no longer has to be set manually. If the add-on option is
  left blank, the init script now generates a 32-byte random value
  with `openssl rand -hex 32` and persists it to `/data/.jwt_secret`
  (mode 0600). Subsequent boots reuse the saved value, so sessions
  survive restarts. Setting `jwt_secret` explicitly in the add-on
  options still wins.
- `20-bootstrap-databases.sh` now refuses to touch `/data/postgres`
  unless `10-render-env.sh` finished successfully (gated on a
  `/run/postiz-config-validated` marker). Previously a misconfigured
  add-on would still run `initdb` and create roles before failing.
- Add `openssl` to the apt install list so the secret generator is
  always available regardless of base-image package set.

## 0.2.0

- Add the `webui` field to `config.yaml`, so the add-on's detail page in
  Home Assistant shows an **OPEN WEB UI** button that links to the
  Postiz UI on the host port you configured. Saves typing the URL.
- README and `DOCS.md` now document how to add an optional Postiz panel
  to the Home Assistant sidebar manually via `panel_iframe` in
  `configuration.yaml`. A built-in sidebar entry is not possible
  without Home Assistant Ingress, and Ingress is blocked by upstream
  Postiz: the frontend hardcodes absolute paths (`/_next/...`,
  `/api/...`) at build time and has no `basePath` support. Tracked
  upstream; this add-on will revisit Ingress once
  `NEXT_PUBLIC_BASE_PATH` (or equivalent) lands in Postiz.

## 0.1.0

Initial release.

- Single-container packaging of Postiz `ghcr.io/gitroomhq/postiz-app`
  for Home Assistant OS.
- Bundled services: PostgreSQL 17, Redis 7, Temporal CLI in
  `server start-dev` mode (SQLite persistence under `/data/temporal`).
- s6-overlay supervises all four long-running services.
- Persistent paths under the add-on's private `/data`:
  - `/data/postgres` - PostgreSQL data directory
  - `/data/redis` - Redis AOF/RDB
  - `/data/temporal` - Temporal SQLite database
  - `/data/uploads` - Postiz user uploads
- Exposes Postiz web UI on container port `5000/tcp` (default host
  port 4007).
- No Home Assistant Ingress yet (Postiz does not currently support a
  path prefix cleanly).
- Architectures: `amd64`, `aarch64`.
