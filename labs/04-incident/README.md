# Lab 04: Incident! The site is down

**Time:** 1–2 hours · **Needs:** Labs 02–03 · **You'll learn:** debugging a live system: reading logs, following requests hop by hop, and writing a postmortem

## 🚨 The ticket

> **SEV-2** · Users report the site is completely down. http://localhost:8400 returns an error page. Nothing was deployed today… except a "small config cleanup" last night. Please fix it ASAP and write up what happened.

Start the "production" stack:

```bash
cd ~/Code/devops-practice/labs/04-incident
docker compose up -d --build
```

## How requests flow

```
your browser ──► proxy (nginx, :8400) ──► web (gunicorn, :8000) ──► cache (redis, :6379, password protected)
```

Something is broken at **more than one** hop. Fix one thing, and the next problem shows up. That's normal and realistic.

## The rules

- You **may** edit `nginx.conf` and `app.env`.
- **Don't** edit `compose.yaml`. Removing the Redis password is not a fix. 😄
- Take notes as you go. You'll need them for `POSTMORTEM.md`.

## A debugging method that works

Don't guess. Work from the outside in, and at each hop ask: *"is this hop healthy, and what does it say about the next one?"*

```bash
curl -i localhost:8400/          # -i shows the status code and headers. Who answered?
docker compose ps                # is everything Up? Anything restarting? Look at STATUS
docker compose logs proxy        # nginx's error log explains a 502
docker compose logs web          # a Python traceback? Read the LAST line first
docker compose logs --tail 20 -f web   # watch live while you retry

# Test from INSIDE the network, skipping hops:
docker compose exec proxy wget -qO- http://web:8000/health
docker compose exec proxy wget -qO- http://web:8000/ready

# Look at what a container actually received:
docker compose exec web env | sort     # only works while web is running
docker compose config                  # the fully resolved config
```

After you change `app.env`, run `docker compose up -d` to recreate `web` (a plain `restart` does **not** re-read env files). After you change `nginx.conf`, `docker compose restart proxy` is enough.

## Done when

```bash
./check.sh
```

This checks that the site works end to end, that Redis still needs a password, and that you've filled in `POSTMORTEM.md` (all the TODOs replaced).

## Hints

Try for at least 20 minutes before opening these. The struggle is the practice.

<details><summary>Hint 1: the first error</summary>

A **502 Bad Gateway** means nginx is fine but couldn't get an answer from the thing *behind* it. `docker compose logs proxy` shows where nginx tried to connect. Compare that with where the app actually listens (Lab 02).
</details>

<details><summary>Hint 2: "Restarting" in docker compose ps</summary>

The web container keeps crashing and restarting. `docker compose logs web` shows a big traceback, and the last lines are gunicorn giving up, which isn't the real cause. Filter for the real error with `docker compose logs web | grep -i error` (Lab 00 skills!). You'll find a `KeyError`. Which environment variable is missing? Now look *very* carefully at the spelling in `app.env`.
</details>

<details><summary>Hint 3: now it's a 500 error</summary>

The logs say `AuthenticationError` or `NOAUTH`. Redis wants a password. Where is the password defined, and how does the app read one? Search `app/app.py` for `environ`: `grep -n environ ../../app/app.py`.
</details>

## Stretch goals

- The Redis password is hardcoded in `compose.yaml` in plain text. Move it to one place (an `.env` file with `${REDIS_PASSWORD}`) so compose.yaml and app.env share it. How do real teams handle this? (Look up Docker secrets and Vault.)
- Why does `/health` succeed while `/` fails? Why is that split useful for load balancers and Kubernetes?
