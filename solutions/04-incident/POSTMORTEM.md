# Postmortem: site down (Lab 04)

## Summary
The site returned 502s, then 500s, for every request. Three config mistakes from the "cleanup" stacked on top of each other.

## Timeline
- `curl -i localhost:8400/` → 502 Bad Gateway from nginx.
- `docker compose logs proxy` → nginx connecting to `web:5000`, connection refused.
- `docker compose ps` → web was in a restart loop. Logs: `KeyError: 'REDIS_HOST'`.
- Fixed nginx port + env typo → now 500. Logs: `redis.exceptions.AuthenticationError`.
- Added REDIS_PASSWORD → 200.

## Root causes
1. nginx proxied to port 5000 (Flask dev-server port); gunicorn listens on 8000.
2. `app.env` had a typo, `REDIS_HSOT`, so the app crashed at startup reading `REDIS_HOST`.
3. Redis requires a password (`--requirepass`) but the app was never given `REDIS_PASSWORD`.

## Fixes
- `nginx.conf`: `http://web:8000`.
- `app.env`: `REDIS_HOST=cache`, `REDIS_PASSWORD=...`. Recreated web with `docker compose up -d`.

## Prevention
- Healthchecks on web plus `depends_on: service_healthy` on the proxy, so a broken app is visible in `docker compose ps`.
- A CI smoke test that brings the stack up and curls `/ready` before merging config changes.
- Keep the password in one shared `.env`/secret instead of copying it by hand.
