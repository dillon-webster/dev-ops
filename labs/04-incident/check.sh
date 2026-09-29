#!/usr/bin/env bash
source "$(dirname "$0")/../lib.sh"
require_docker
cd "$REPO_ROOT/labs/04-incident"

title "Lab 04: Incident"

check "Redis still requires a password (compose.yaml untouched)" "put the requirepass back. Removing auth isn't a fix" \
  grep -q 'requirepass", "s3cret-lab04' compose.yaml

port_owner_warning 8400 devops-lab04
info "making sure the stack is up with your latest changes..."
docker compose up -d --build --wait --wait-timeout 60 >/dev/null 2>&1
wait_for_url http://localhost:8400/health 20

headers=$(curl -sS -D - -o /dev/null localhost:8400/ 2>/dev/null)
check "requests go through nginx" "the response should come from the proxy container on port 8400" \
  grep -qi '^server: nginx' <<<"$headers"

code=$(curl -s -o /dev/null -w '%{http_code}' localhost:8400/)
check "GET / returns 200 (got $code)" "follow the request hop by hop. See the method in the README" test "$code" = 200

check "GET /ready returns 200 (app ↔ redis is healthy)" "curl -i localhost:8400/ready and read the error" \
  curl -fsS localhost:8400/ready

check "unauthenticated redis access is refused" "don't disable the password. Give the app the password instead" \
  sh -c "docker compose exec -T cache redis-cli ping 2>&1 | grep -q NOAUTH"

check "web container is stable (no restarts in the last 10s)" "docker compose ps: is web restarting?" \
  sh -c 'r1=$(docker inspect -f "{{.RestartCount}}" devops-lab04-web-1); sleep 10; r2=$(docker inspect -f "{{.RestartCount}}" devops-lab04-web-1); [ "$r1" = "$r2" ] && [ "$(docker inspect -f "{{.State.Running}}" devops-lab04-web-1)" = true ]'

check "POSTMORTEM.md has no TODOs left" "fill in every section of POSTMORTEM.md" \
  sh -c "! grep -q 'TODO' POSTMORTEM.md"
check "POSTMORTEM.md names all three root causes" "mention the port, the env var typo, and the missing redis password" \
  sh -c "grep -qiE '5000|8000|port' POSTMORTEM.md && grep -qiE 'HSOT|typo|REDIS_HOST' POSTMORTEM.md && grep -qiE 'password|auth' POSTMORTEM.md"

summary
