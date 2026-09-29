# Lab 02: Fix a bad Dockerfile

**Time:** ~1 hour · **You'll learn:** writing Dockerfiles, layer caching, `.dockerignore`, non-root users, keeping secrets out of images, healthchecks

## The situation

A coworker wrote `app/Dockerfile` for our little visit-counter service (`app/app.py`). It "works", but it would never pass a review. Your job is to fix it. You'll edit two files:

- `app/Dockerfile`
- `app/.dockerignore` (you create this one)

## Some background first

**Layers and caching.** Each instruction in a Dockerfile (`FROM`, `COPY`, `RUN`…) creates a *layer*. Docker caches layers. When you rebuild, it reuses cached layers until it reaches the first instruction whose inputs changed, and rebuilds everything from that point down. So the order of instructions matters a lot: put things that rarely change (installing dependencies) *above* things that change all the time (your code).

**Build context.** `docker build app/` sends the *whole* `app/` folder to Docker, including junk and secrets. A `.dockerignore` file works like `.gitignore` and controls what gets left out.

**Secrets.** Anything in an `ENV` line or a `COPY`'d file is baked into the image permanently. Anyone who can pull the image can read it with `docker history` or `docker inspect`. Secrets should be passed in when the container *runs* (`docker run -e API_KEY=...`), never when it's built.

**Root.** By default, containers run as root. If someone breaks into your app, root makes the damage much worse. Create a normal user and switch to it with `USER`.

## Try the bad version first

```bash
cd ~/Code/devops-practice
docker build -t devops-app:bad app/
docker images devops-app                                       # look at DISK USAGE and CONTENT SIZE 😬
docker history --no-trunc devops-app:bad | grep supersecret    # the "secret" is right there
docker run --rm devops-app:bad whoami                          # root
docker run --rm devops-app:bad ls -a /app                      # .env and notes/ got copied in
```

## Your task

Fix `app/Dockerfile` so that the image:

1. **Is small.** Under 150 MB of *content size* (the `CONTENT SIZE` column in `docker images`; the bad one is ~400 MB, and 1.6 GB on disk). Hint: the `python:3.12-slim` base image.
2. **Caches dependencies.** Changing `app.py` must *not* make `pip install` run again. Copy `requirements.txt` and install *before* copying the rest of the code.
3. **Contains no secrets.** No `API_KEY` anywhere in the image.
4. **Has only what it needs.** No `.env`, `notes/` or `tests/` inside the image (use `.dockerignore`).
5. **Runs as a non-root user.**
6. **Uses a real server.** `gunicorn -b 0.0.0.0:8000 app:app` on port **8000** instead of Flask's debug server. Use the *exec form* of CMD (JSON array: `CMD ["gunicorn", ...]`).
7. **Has a HEALTHCHECK** that hits `/health`. (The slim image doesn't include `curl`, but it does have `python`…)
8. **Doesn't hardcode `REDIS_HOST=localhost`.** That's the wrong value everywhere except a laptop. It gets set at runtime.

Try it yourself:

```bash
docker build -t devops-app:latest app/
docker run --rm -d --name lab02 -p 8000:8000 -e REDIS_HOST=nowhere devops-app:latest
curl localhost:8000/health        # {"status":"ok"}
curl localhost:8000/ready         # 503, because there's no Redis yet. That's expected! Lab 03 fixes it.
docker ps                         # after ~30s the STATUS column should say (healthy)
docker rm -f lab02
```

Then grade it (this builds the image for you):

```bash
./labs/02-dockerfile/check.sh
```

## Hints

<details><summary>What does a good layer order look like?</summary>

```
FROM ...
(env vars / settings that never change)
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
(create user)
COPY . .
USER ...
EXPOSE / HEALTHCHECK / CMD
```
</details>

<details><summary>Creating a user</summary>

On Debian-based images (which `-slim` is): `RUN useradd --create-home --uid 10001 appuser`, then `USER appuser` later on. Using a numeric UID is a nice touch, because Kubernetes can then verify the container isn't root.
</details>

<details><summary>HEALTHCHECK without curl</summary>

```dockerfile
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')" || exit 1
```
</details>

<details><summary>Nice extras</summary>

`ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1` stops Python from writing `.pyc` files and makes logs show up immediately in `docker logs`. The second one matters a lot.
</details>

## Stretch goals

- Look into **multi-stage builds**: install dependencies in one stage and copy them into a clean final stage.
- Run `docker scout quickview devops-app:latest` (or `trivy image devops-app:latest`) to scan for CVEs.
- Pin the base image by digest (`python:3.12-slim@sha256:...`). Why would you want that?
