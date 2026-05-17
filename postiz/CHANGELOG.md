# Changelog

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
