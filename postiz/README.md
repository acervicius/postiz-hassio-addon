# Postiz

Self-hosted [Postiz](https://github.com/gitroomhq/postiz-app) social
media scheduler, packaged as a Home Assistant Add-on.

This is an unofficial community packaging. See the repository root
[README](https://github.com/acervicius/postiz-hassio-addon) for the
project overview, install steps, and limitations.

## Quick start

1. Install this add-on from the Home Assistant Add-on Store (after
   adding this repository as a custom repository).
2. On the **Configuration** tab, set:
   - `main_url` - the URL you will reach Postiz at, including port
     (for example `http://homeassistant.local:4007`).
   - `jwt_secret` - any long random string. The add-on does not
     generate one for you; run `openssl rand -hex 32` if you need one.
3. Start the add-on. The first boot runs `initdb` against
   `/data/postgres` and applies the Postiz schema, which takes
   30-90 seconds; subsequent boots are immediate.
4. Open the URL you configured as `main_url` in your browser.

See `DOCS.md` for the full configuration reference.

## What runs inside the container

- Postiz (copied from `ghcr.io/gitroomhq/postiz-app`)
- PostgreSQL 17, bound to `127.0.0.1` only
- Redis 7, bound to `127.0.0.1` only
- Temporal in `server start-dev` mode with SQLite persistence

All four processes are supervised by s6-overlay.
