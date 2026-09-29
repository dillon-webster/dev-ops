#!/usr/bin/env bash
source "$(dirname "$0")/../lib.sh"
require_docker
cd "$REPO_ROOT/labs/03-compose"
dc() { docker compose "$@"; }

title "Lab 03: Docker Compose"

cfg=$(dc config --format json 2>/tmp/lab03-config.err)
if [ -z "$cfg" ]; then
  fail "compose.yaml is valid" "run: docker compose config"; cat /tmp/lab03-config.err; summary
fi
pass "compose.yaml is valid"
q() { python3 -c "import json,sys; d=json.load(sys.stdin); print(eval(sys.argv[1]))" "$1" <<<"$cfg" 2>/dev/null; }

check "cache has a healthcheck" "add a healthcheck using redis-cli ping" \
  test -n "$(q "d['services']['cache'].get('healthcheck',{}).get('test') or ''")"
check "web waits for cache to be healthy" "depends_on: cache: condition: service_healthy" \
  test "$(q "d['services']['web'].get('depends_on',{}).get('cache',{}).get('condition')")" = service_healthy
check "both services have a restart policy" "restart: unless-stopped" \
  sh -c "[ -n \"$(q "d['services']['web'].get('restart') or ''")\" ] && [ -n \"$(q "d['services']['cache'].get('restart') or ''")\" ]"
check "cache stores /data in a named volume" "volumes: - redis-data:/data (and a top-level volumes: section)" \
  test "$(q "[v['type'] for v in d['services']['cache'].get('volumes',[]) if v['target']=='/data'][0]")" = volume
check "redis runs with --appendonly yes" 'command: ["redis-server", "--appendonly", "yes"]' \
  sh -c "q=\"$(q "' '.join(d['services']['cache'].get('command') or [])")\"; echo \"\$q\" | grep -q 'appendonly yes'"
check ".env file sets GREETING" "create labs/03-compose/.env with GREETING=something" \
  grep -qE '^GREETING=.+' .env
greeting=$(grep -E '^GREETING=' .env 2>/dev/null | head -1 | cut -d= -f2- | tr -d "\"'")
check "compose.yaml reads GREETING from .env (not hardcoded)" 'environment: GREETING: ${GREETING}' \
  sh -c "grep -q '\${GREETING' compose.yaml"

port_owner_warning 8300 devops-lab03
info "starting the stack (docker compose up -d --build --wait)..."
if dc up -d --build --wait --wait-timeout 90 >/tmp/lab03-up.log 2>&1; then
  pass "stack starts and becomes healthy"
else
  fail "stack starts and becomes healthy" "docker compose ps / docker compose logs"; tail -15 /tmp/lab03-up.log
fi

wait_for_url http://localhost:8300/health 20
first=$(curl -fsS localhost:8300/ 2>/dev/null)
second=$(curl -fsS localhost:8300/ 2>/dev/null)
v1=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['visits'])" "$first" 2>/dev/null)
v2=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['visits'])" "$second" 2>/dev/null)
check "http://localhost:8300/ counts visits" "is REDIS_HOST the *service name* of redis? check: docker compose logs web" \
  test -n "$v1" -a -n "$v2" -a "${v2:-0}" -gt "${v1:-0}"
check "greeting in the response matches .env" "GREETING: \${GREETING} under web.environment" \
  test "$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['message'])" "$second" 2>/dev/null)" = "$greeting"

info "restarting the stack to test persistence (down, then up)..."
dc down >/dev/null 2>&1
dc up -d --wait --wait-timeout 90 >/dev/null 2>&1
wait_for_url http://localhost:8300/health 20
v3=$(curl -fsS localhost:8300/ 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['visits'])" 2>/dev/null)
check "visit count survives docker compose down/up (${v2:-?} → ${v3:-?})" "named volume at /data + --appendonly yes" \
  test -n "$v3" -a "${v3:-0}" -gt "${v2:-0}"

summary
