#!/usr/bin/env bash
source "$(dirname "$0")/../lib.sh"
cd "$REPO_ROOT"
[ -d .venv ] && PATH="$REPO_ROOT/.venv/bin:$PATH"

title "Lab 06: CI"

check "ruff and pytest are installed (venv)" "python3 -m venv .venv && source .venv/bin/activate && pip install -r app/requirements-dev.txt" \
  sh -c "command -v ruff && command -v pytest && python3 -c 'import yaml'"

out=$(make lint 2>&1); rc=$?
if [ $rc -eq 0 ] && grep -qi ruff Makefile; then pass "make lint passes"; else
  fail "make lint passes" "fill in the lint target, then fix what ruff reports"; echo "$out" | tail -6 | sed 's/^/      /'; fi

out=$(make test 2>&1); rc=$?
if [ $rc -eq 0 ] && grep -q "passed" <<<"$out"; then pass "make test passes"; else
  fail "make test passes" "fill in the test target (pytest needs REDIS_HOST set)"; echo "$out" | tail -6 | sed 's/^/      /'; fi

check "make build target uses docker build" "build: docker build -t devops-app:latest app" \
  sh -c "make -n build | grep -qE '^docker build'"

WF=.github/workflows/ci.yml
check "$WF exists" "create it at the repo root, not in labs/06-ci" test -f "$WF"
[ -f "$WF" ] || summary

[ -t 1 ] && export COLOR=1
pyout=$(python3 - "$WF" <<'PY'
import sys, yaml

import os
G, R, Y, N = ("\033[32m", "\033[31m", "\033[33m", "\033[0m") if os.environ.get("COLOR") else ("",) * 4
ok = bad = 0
def result(cond, desc, hint):
    global ok, bad
    if cond:
        ok += 1; print(f"  {G}✔{N} {desc}")
    else:
        bad += 1; print(f"  {R}✘{N} {desc}\n      {Y}hint:{N} {hint}")

try:
    wf = yaml.safe_load(open(sys.argv[1]))
except yaml.YAMLError as e:
    print(f"  {R}✘{N} ci.yml is valid YAML\n      {e}"); sys.exit(1)
result(isinstance(wf, dict), "ci.yml is valid YAML", "check indentation (spaces, not tabs)")
if not isinstance(wf, dict): sys.exit(1)

# YAML 1.1 quirk: an unquoted `on:` key is parsed as the boolean True.
on = wf.get("on", wf.get(True))
events = set(on) if isinstance(on, (list, dict)) else {on} if on else set()
result("push" in events and "pull_request" in events, "triggers on push and pull_request", "on: push and pull_request")

jobs = wf.get("jobs") or {}
test, build = jobs.get("test") or {}, jobs.get("build") or {}
result(bool(test), "has a job named 'test'", "jobs: test:")
result(bool(build), "has a job named 'build'", "jobs: build:")

steps = test.get("steps") or []
uses = [s.get("uses", "") for s in steps]
runs = "\n".join(s.get("run", "") for s in steps)
result(test.get("runs-on") == "ubuntu-latest", "test runs on ubuntu-latest", "runs-on: ubuntu-latest")
result(any(u.startswith("actions/checkout@") for u in uses), "test checks out the code", "uses: actions/checkout@v5")
sp = next((s for s in steps if s.get("uses", "").startswith("actions/setup-python@")), None)
result(sp is not None and str((sp.get("with") or {}).get("python-version")) == "3.12",
       "test sets up Python 3.12", 'uses: actions/setup-python@v6 with python-version: "3.12" (quoted!)')
result(sp is not None and (sp.get("with") or {}).get("cache") == "pip", "pip caching is enabled", "with: cache: pip")
result("requirements-dev.txt" in runs, "installs dev requirements", "run: pip install -r app/requirements-dev.txt")
result("make lint" in runs and "make test" in runs, "runs make lint and make test", "run: make lint / run: make test")

needs = build.get("needs")
needs = [needs] if isinstance(needs, str) else needs or []
result("test" in needs, "build only runs after test passes", "needs: test")
bruns = "\n".join(s.get("run", "") for s in build.get("steps") or [])
buses = [s.get("uses", "") for s in build.get("steps") or []]
result("make build" in bruns and any(u.startswith("actions/checkout@") for u in buses),
       "build checks out the code and runs make build", "build needs its own checkout step. Jobs run on separate machines!")

print(f"__COUNTS__ {ok} {bad}")
sys.exit(0)
PY
)
grep -v __COUNTS__ <<<"$pyout"
read -r _ ok bad <<<"$(grep __COUNTS__ <<<"$pyout")"
PASSED=$((PASSED + ${ok:-0})); FAILED=$((FAILED + ${bad:-1}))

summary
