#!/usr/bin/env bash
source "$(dirname "$0")/../lib.sh"
require_docker
cd "$REPO_ROOT/labs/07-observability"
PROM=http://localhost:9700
GRAF=http://localhost:3700
j() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)" 2>/dev/null; }

title "Lab 07: Monitoring"

for p in 8700 9700 3700; do port_owner_warning $p devops-lab07; done
info "bringing the stack up and reloading config..."
docker compose up -d --build --wait --wait-timeout 90 >/dev/null 2>&1
docker compose restart prometheus grafana >/dev/null 2>&1
wait_for_url "$PROM/-/ready" 30 || { fail "Prometheus is running" "docker compose logs prometheus (probably a YAML error)"; docker compose logs --tail 5 prometheus; summary; }
pass "Prometheus is running"

info "waiting for the first scrapes..."
health=""
for _ in $(seq 1 15); do
  health=$(curl -fsS "$PROM/api/v1/targets" | j "[t['health'] for t in d['data']['activeTargets'] if t['labels'].get('job')=='app']")
  [ "$health" = "['up']" ] && break; sleep 1
done
check "a scrape job named 'app' exists" "add job_name: app to prometheus.yml" sh -c "[ -n \"$health\" ] && [ \"$health\" != '[]' ]"
check "the app target is UP" "target should be web:8000 (service name + container port)" test "$health" = "['up']"

for _ in $(seq 1 20); do curl -fsS localhost:8700/ >/dev/null 2>&1; done
sleep 6
n=$(curl -fsS "$PROM/api/v1/query" --data-urlencode 'query=app_requests_total{job="app",endpoint="/"}' | j "len(d['data']['result'])")
check "Prometheus has app_requests_total from the app" "is the app target UP?" test "${n:-0}" -ge 1

rule=$(curl -fsS "$PROM/api/v1/rules" | j "[r for g in d['data']['groups'] for r in g['rules'] if r.get('name')=='AppDown']")
check "an alert named AppDown is loaded" "write it in alerts.yml; validate with promtool (see hints)" sh -c "[ -n \"\$0\" ] && [ \"\$0\" != '[]' ]" "$rule"
check "AppDown checks the up metric" 'expr: up{job="app"} == 0' grep -q "up" <<<"$rule"
check "AppDown waits 15s before firing" "for: 15s" grep -q "'duration': 15" <<<"$rule"
check "AppDown has severity: critical" "labels: severity: critical" grep -q "'severity': 'critical'" <<<"$rule"
check "AppDown has a summary annotation" "annotations: summary: ..." grep -q "'summary'" <<<"$rule"

info "stopping web to see if AppDown fires (up to ~45s)..."
docker compose stop web >/dev/null 2>&1
state=""
[ "$rule" != "[]" ] && [ -n "$rule" ] && for _ in $(seq 1 45); do
  state=$(curl -fsS "$PROM/api/v1/alerts" | j "[a['state'] for a in d['data']['alerts'] if a['labels'].get('alertname')=='AppDown']")
  [ "$state" = "['firing']" ] && break; sleep 1
done
docker compose start web >/dev/null 2>&1
check "AppDown fires when the app is down" "expr must become true when the target is down" test "$state" = "['firing']"

wait_for_url "$GRAF/api/health" 40
ds=$(curl -fsS "$GRAF/api/datasources/name/Prometheus" 2>/dev/null)
check "Grafana has a data source named Prometheus" "grafana/provisioning/datasources/prometheus.yml, then docker compose restart grafana" \
  test -n "$ds"
uid=$(j "d['uid']" <<<"$ds")
dsh=$(curl -fsS "$GRAF/api/datasources/uid/$uid/health" 2>/dev/null | j "d['status']")
check "Grafana can query Prometheus through it" "url should be http://prometheus:9090 (service name, container port)" test "$dsh" = OK

summary
