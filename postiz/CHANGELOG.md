# Changelog

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
