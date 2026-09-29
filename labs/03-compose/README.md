# Lab 03: Docker Compose

**Time:** ~1 hour · **Needs:** Lab 02 done (a working `app/Dockerfile`) · **You'll learn:** multi-container apps, service networking, volumes, healthchecks, startup order, `.env` files

## The idea

Real apps are more than one container. Our app needs **Redis** to store its visit counter. Typing a long `docker run` command for each container gets old fast, so **Docker Compose** describes the whole stack in one YAML file:

```bash
docker compose up -d --build     # build images and start everything in the background
docker compose ps                # what's running (and is it healthy?)
docker compose logs -f web       # follow logs for one service
docker compose exec cache sh     # shell into a running service
docker compose down              # stop and remove containers (volumes are kept)
docker compose down -v           # ...and delete volumes too (the data is gone!)
docker compose config            # print the final config. Great for catching typos
```

Run these from this lab's folder, where `compose.yaml` lives.

**Networking.** Compose puts every service on a shared network where each **service name is a hostname**. From inside `web`, Redis is reachable at `cache:6379`. `localhost` inside a container means *that container itself*, never your Mac and never the other containers.

## Your task

`compose.yaml` starts, but it's broken. Fix it so that:

1. **The app is reachable at http://localhost:8300.** (Right now the port mapping picks a random host port. Run `docker compose ps` to see it.)
2. **The app can talk to Redis.** `curl localhost:8300/` should return JSON with a `visits` count that goes up every time.
3. **Redis data survives restarts.** Run `docker compose down` then `docker compose up -d`, and the count keeps going instead of resetting to 1. You'll need:
   - a **named volume** mounted at `/data` in the `cache` service
   - Redis told to save to disk: `command: ["redis-server", "--appendonly", "yes"]`
4. **Redis has a healthcheck** (`redis-cli ping` should answer `PONG`).
5. **web waits for Redis to be *healthy*** before starting (not just *started*). Look up the long form of `depends_on`.
6. **Both services restart automatically** if they crash (`restart: unless-stopped`).
7. **The greeting comes from a `.env` file.** Create `labs/03-compose/.env` containing `GREETING=...` (anything you like). In compose.yaml, set `GREETING: ${GREETING}`. Compose reads `.env` automatically. This is how you keep settings (and secrets) out of the YAML.

Then grade it:

```bash
./check.sh
```

The checker restarts your stack to test persistence, so don't be surprised by that.

## Explore (not graded, very worth doing)

```bash
docker compose exec web python -c "import socket; print(socket.gethostbyname('cache'))"  # DNS in action
docker compose exec cache redis-cli get visits
docker compose stop cache && curl -i localhost:8300/ready    # what does the app say now?
docker compose start cache
docker volume ls                                               # find your volume
docker compose up -d --scale web=3    # fails! Why? (Hint: ports.) How would you fix it?
```

## Hints

<details><summary>Port syntax</summary>

`"8000"` means "container port 8000, on a random host port". The format is `"HOST:CONTAINER"`.
</details>

<details><summary>Named volume syntax</summary>

```yaml
services:
  cache:
    volumes:
      - redis-data:/data

volumes:
  redis-data:
```
</details>

<details><summary>Healthcheck + depends_on</summary>

```yaml
  cache:
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

  web:
    depends_on:
      cache:
        condition: service_healthy
```
</details>

## Clean up

```bash
docker compose down -v
```
