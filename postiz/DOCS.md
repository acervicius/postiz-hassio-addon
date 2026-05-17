# Postiz add-on configuration reference

All options below appear on the add-on's **Configuration** tab in
Home Assistant. Required options must be set before the add-on will
start successfully.

## Required

### `main_url`

The full external URL you will use to reach Postiz, including the
scheme and host port. Example: `http://homeassistant.local:4007`.

This is passed to Postiz as `MAIN_URL`, `FRONTEND_URL`, and forms
`NEXT_PUBLIC_BACKEND_URL` (`<main_url>/api`). OAuth redirects from
social platforms come back to this URL, so it must match the URL you
actually open in your browser.

### `jwt_secret`

A long random string used to sign Postiz session tokens. Treat it as
sensitive. If you change it, all existing user sessions are invalidated.

Generate one with `openssl rand -hex 32`.

## Common

### `log_level`

One of `debug`, `info`, `warn`, `error`. Default `info`. Currently
only affects the add-on's own bootstrap scripts; Postiz itself uses
its own logging configuration.

### `storage_provider`

`local` (default) stores uploaded media under `/data/uploads` inside
the add-on. `cloudflare` uses Cloudflare R2; if you choose
`cloudflare` you must also fill in the `cloudflare_*` options below.

### `disable_registration`

If `true`, the public sign-up form is disabled. Use this after you
have created your own account so the instance is not open to the
internet.

## Cloudflare R2 (only if `storage_provider` is `cloudflare`)

- `cloudflare_account_id`
- `cloudflare_access_key`
- `cloudflare_secret_access_key`
- `cloudflare_bucket_name`
- `cloudflare_bucket_url`
- `cloudflare_region` (default `auto`)

## Social platform OAuth credentials

Each platform is optional. Fill in only the credentials for the
platforms you want to publish to. You obtain these from each
platform's developer console; the redirect URL you register there
must point back to your `main_url`.

| Option                    | Postiz env var          |
| ------------------------- | ----------------------- |
| `facebook_app_id`         | `FACEBOOK_APP_ID`       |
| `facebook_app_secret`     | `FACEBOOK_APP_SECRET`   |
| `threads_app_id`          | `THREADS_APP_ID`        |
| `threads_app_secret`      | `THREADS_APP_SECRET`    |
| `x_url`                   | `X_URL`                 |
| `x_api_key`               | `X_API_KEY`             |
| `x_api_secret`            | `X_API_SECRET`          |
| `linkedin_client_id`      | `LINKEDIN_CLIENT_ID`    |
| `linkedin_client_secret`  | `LINKEDIN_CLIENT_SECRET`|
| `youtube_client_id`       | `YOUTUBE_CLIENT_ID`     |
| `youtube_client_secret`   | `YOUTUBE_CLIENT_SECRET` |
| `reddit_client_id`        | `REDDIT_CLIENT_ID`      |
| `reddit_client_secret`    | `REDDIT_CLIENT_SECRET`  |

Instagram is reached through Postiz's Threads integration; there is no
separate Instagram option. Telegram is not a Postiz OAuth target and
is intentionally not exposed.

### `openai_api_key`

Optional. If set, Postiz uses it for AI-assisted caption generation.

## Persistent storage

The add-on's private `/data` directory is laid out as:

- `/data/postgres` - PostgreSQL 17 data directory (`initdb` runs on
  first boot if empty)
- `/data/redis` - Redis AOF/RDB dumps
- `/data/temporal` - Temporal SQLite database
- `/data/uploads` - Postiz user uploads when `storage_provider=local`

Everything under `/data` is included in Home Assistant snapshots
automatically. Stopping the add-on does not delete this data.

## Networking

The add-on exposes a single TCP port. Inside the container, Postiz's
nginx listens on `5000`. By default Home Assistant maps that to host
port `4007`; change the host side in the **Network** tab of the
add-on if you need a different port.

PostgreSQL (`5432`), Redis (`6379`), and Temporal (`7233`) are bound
to `127.0.0.1` inside the container and are not reachable from
outside. This is intentional: it avoids any conflict with separate
Home Assistant PostgreSQL or Redis add-ons running on the same host.

## Opening the web UI

The add-on detail page in Home Assistant shows an **OPEN WEB UI**
button (driven by the `webui` field in the add-on manifest). Clicking
it opens Postiz on whatever host port `5000/tcp` is mapped to.

If you want Postiz in the HA sidebar, add a `panel_iframe` entry to
your `configuration.yaml`:

    panel_iframe:
      postiz:
        title: Postiz
        icon: mdi:calendar-clock
        url: "http://homeassistant.local:4007"
        require_admin: true

This is the HA-standard way to frame an external page in the sidebar.
A native add-on sidebar entry (`panel_icon` / `panel_title` in the
manifest) requires Home Assistant Ingress, which is not yet available
for this add-on - see the "Known limitations" section in the
repository README for why.
