# Postiz Home Assistant Add-on (community)

An unofficial Home Assistant Add-on that packages
[Postiz](https://github.com/gitroomhq/postiz-app), the open-source social
media scheduler, as a single container suitable for a Home Assistant OS
instance.

This repository is not affiliated with Gitroom or the Postiz project. It
exists to make Postiz easy to install for Home Assistant users who would
rather not run a separate Docker host.

## What you get

A single add-on (`Postiz`) that bundles, in one container supervised by
s6-overlay:

- Postiz (the upstream `ghcr.io/gitroomhq/postiz-app` image, copied in
  by digest at build time)
- PostgreSQL 17 (private, bound to `127.0.0.1` only)
- Redis 7 (private, bound to `127.0.0.1` only)
- Temporal (the official `temporal` CLI run as `server start-dev` with
  SQLite persistence under `/data/temporal`)

All persistent state lives in the add-on's private `/data` directory, so
Home Assistant's native snapshot mechanism backs it up automatically.

## Supported architectures

- `amd64`
- `aarch64`

`armv7`, `armhf`, and `i386` are intentionally unsupported because
upstream Postiz does not reliably build for them.

## Install

1. In Home Assistant, open **Settings -> Add-ons -> Add-on Store**.
2. Click the three-dot menu in the top right, choose **Repositories**,
   and add:

       https://github.com/acervicius/postiz-hassio-addon

3. The **Postiz** add-on appears at the bottom of the store. Install it.
4. Open the add-on's **Configuration** tab, set at minimum:
   - `main_url` - the URL you will access Postiz at, including scheme
     and port (for example `http://homeassistant.local:4007`)
   - `jwt_secret` - a long random string (the add-on does not generate
     one for you; use `openssl rand -hex 32` or similar)
5. Start the add-on. First boot takes 30-90 seconds while PostgreSQL
   initialises its data directory.
6. Browse to the URL you set as `main_url`.

## Configuring social platforms

Postiz authenticates to each social platform with OAuth credentials you
register yourself in that platform's developer console. The add-on
exposes the same environment variables Postiz upstream documents:

| Add-on option                          | Postiz env var          |
| -------------------------------------- | ----------------------- |
| `facebook_app_id` / `_secret`          | `FACEBOOK_APP_ID/SECRET`|
| `threads_app_id` / `_secret`           | `THREADS_APP_ID/SECRET` |
| `x_api_key` / `_secret` / `x_url`      | `X_API_KEY/SECRET/URL`  |
| `linkedin_client_id` / `_secret`       | `LINKEDIN_CLIENT_ID/SECRET` |
| `youtube_client_id` / `_secret`        | `YOUTUBE_CLIENT_ID/SECRET`  |
| `reddit_client_id` / `_secret`         | `REDDIT_CLIENT_ID/SECRET`   |

Instagram is reached through the Threads integration, which is how
upstream Postiz models it. Telegram is not currently a Postiz OAuth
target and is therefore not exposed by this add-on.

See `postiz/DOCS.md` for the full option reference.

## Known limitations (v0.1)

- **No Home Assistant Ingress.** Postiz is reached on the host port you
  map to the container's `5000/tcp`. Ingress requires Postiz to run
  behind a path prefix and is deferred to a later release.
- **Single container.** PostgreSQL, Redis, Temporal, and Postiz all run
  inside one container under s6-overlay. This is intentional for v0.1
  to keep installation to a single click.
- **Temporal runs in `start-dev` mode** with SQLite persistence. This is
  the supported single-node configuration from Temporal upstream. It is
  fine for one user on one laptop; it is not a clustered deployment.
- **Elasticsearch is omitted.** Temporal's advanced visibility features
  (full-text workflow search) are unavailable; basic visibility works.
- **No Home Assistant user federation.** Postiz keeps its own user
  accounts.

## Upstream attribution and license

Postiz is licensed under the GNU Affero General Public License v3.0 by
Nevo David and contributors. This repository repackages Postiz in
compliance with the AGPL and is itself released under AGPL-3.0; see
[`LICENSE`](LICENSE).

- Upstream project: https://github.com/gitroomhq/postiz-app
- Upstream Docker image: `ghcr.io/gitroomhq/postiz-app`
- The unmodified Postiz application code is shipped inside the add-on
  image at `/usr/share/postiz`, including its own `LICENSE` file.

If you modify Postiz itself, AGPL section 13 requires you to offer the
modified source to your users; this add-on does not modify Postiz, only
the surrounding init and supervision.

## Reporting issues

For bugs in the add-on packaging (init scripts, configuration schema,
service supervision), open an issue here. For bugs in Postiz itself
(the UI, scheduling logic, social integrations), report upstream at
https://github.com/gitroomhq/postiz-app/issues.
