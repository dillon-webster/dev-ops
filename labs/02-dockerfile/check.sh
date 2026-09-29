#!/usr/bin/env bash
source "$(dirname "$0")/../lib.sh"
require_docker
APP="$REPO_ROOT/app"
IMG=devops-app:latest
NAME=lab02-check

title "Lab 02: Fix a bad Dockerfile"
cleanup() { docker rm -f "$NAME" >/dev/null 2>&1; [ -n "${TMP:-}" ] && rm -rf "$TMP"; }
trap cleanup EXIT

info "building $IMG (first build can take a minute)..."
if docker build -q -t "$IMG" "$APP" >/tmp/lab02-build.log 2>&1; then
  pass "image builds"
else
  fail "image builds" "run: docker build -t $IMG app/   and read the error"
  cat /tmp/lab02-build.log | tail -20; summary
fi

size=$(docker image inspect -f '{{.Size}}' "$IMG")
size_mb=$((size / 1000 / 1000))
check "image content size is under 150 MB (it's ${size_mb} MB; the bad one is ~400)" "use a -slim base image and pip install --no-cache-dir" \
  test "$size_mb" -lt 150

check "no secret in the image's environment or history" "delete the ENV API_KEY line; secrets go in at runtime" \
  sh -c "! { docker image inspect $IMG; docker history --no-trunc $IMG; } | grep -q supersecret"

check "REDIS_HOST is not hardcoded in the image" "remove ENV REDIS_HOST; it's set at runtime (-e REDIS_HOST=...)" \
  sh -c "! docker image inspect -f '{{json .Config.Env}}' $IMG | grep -q REDIS_HOST"

user=$(docker image inspect -f '{{.Config.User}}' "$IMG")
check "runs as a non-root user (USER is '${user:-<unset>}')" "create a user with useradd and switch with USER" \
  sh -c "[ -n '$user' ] && [ '$user' != root ] && [ '$user' != 0 ] && [ \"\$(docker run --rm --entrypoint id $IMG -u)\" != 0 ]"

files=$(docker run --rm --entrypoint sh "$IMG" -c 'ls -a' 2>/dev/null)
check ".env is not in the image" "create app/.dockerignore and list .env in it" sh -c "! grep -qx .env <<<'$files'"
check "notes/ and tests/ are not in the image" "add notes/ and tests/ to .dockerignore" \
  sh -c "! grep -qxE 'notes|tests' <<<'$files'"
check "app.py is in the working directory" "WORKDIR /app then COPY . ." grep -qx app.py <<<"$files"

check "CMD uses exec form (JSON array)" 'CMD ["gunicorn", "-b", "0.0.0.0:8000", "app:app"]' \
  sh -c "docker image inspect -f '{{json .Config.Cmd}}' $IMG | grep -q '^\[\"gunicorn'"

check "a HEALTHCHECK is defined" "add a HEALTHCHECK instruction" \
  sh -c "docker image inspect -f '{{json .Config.Healthcheck}}' $IMG | grep -q Test"

docker run -d --name "$NAME" -p 18000:8000 -e REDIS_HOST=nowhere "$IMG" >/dev/null 2>&1
if wait_for_url http://localhost:18000/health 20; then
  pass "container serves /health on port 8000"
else
  fail "container serves /health on port 8000" "docker logs $NAME  (is gunicorn binding 0.0.0.0:8000?)"
  docker logs "$NAME" 2>&1 | tail -10
fi

info "waiting for Docker to report the container healthy..."
healthy=no
docker image inspect -f '{{json .Config.Healthcheck}}' "$IMG" | grep -q Test && for _ in $(seq 1 40); do
  [ "$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$NAME" 2>/dev/null)" = healthy ] && { healthy=yes; break; }
  sleep 1
done
check "Docker reports the container (healthy)" "check your HEALTHCHECK command; try running it with docker exec" test "$healthy" = yes

# Cache test: rebuild a copy with app.py changed; pip install must come from cache.
TMP=$(mktemp -d)
cp -R "$APP"/. "$TMP"/
docker build -q -t devops-app:cache-test "$TMP" >/dev/null 2>&1
echo "# cache test $(date +%s)" >> "$TMP/app.py"
out=$(docker build --progress=plain -t devops-app:cache-test "$TMP" 2>&1)
step=$(grep -E '^#[0-9]+ \[.*\] RUN .*pip install' <<<"$out" | head -1 | sed -E 's/^#([0-9]+).*/\1/')
check "changing app.py doesn't re-run pip install (layer caching)" "COPY requirements.txt and pip install BEFORE COPY . ." \
  sh -c "[ -n '$step' ] && grep -qE '^#$step CACHED' <<<\"\$0\"" "$out"
docker image rm devops-app:cache-test >/dev/null 2>&1

summary
