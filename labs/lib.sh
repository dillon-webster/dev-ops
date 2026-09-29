# Shared helpers for check.sh scripts. Source this, don't run it.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASSED=0
FAILED=0

if [ -t 1 ]; then G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; B=$'\e[1m'; N=$'\e[0m'; else G= R= Y= B= N=; fi

title() { echo; echo "${B}== $* ==${N}"; }
pass()  { echo "  ${G}✔${N} $1"; PASSED=$((PASSED + 1)); }
fail()  { echo "  ${R}✘${N} $1"; [ -n "${2:-}" ] && echo "      ${Y}hint:${N} $2"; FAILED=$((FAILED + 1)); }
info()  { echo "  · $*"; }

# check "description" "hint" command...
check() {
  local desc="$1" hint="$2"; shift 2
  if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc" "$hint"; fi
}

# Wait up to $2 seconds for URL $1 to return 2xx.
wait_for_url() {
  local url="$1" timeout="${2:-30}" i=0
  until curl -fsS -o /dev/null "$url" 2>/dev/null; do
    i=$((i + 1)); [ "$i" -ge "$timeout" ] && return 1; sleep 1
  done
}

require_docker() {
  if ! docker info >/dev/null 2>&1; then
    echo "${R}Docker isn't running.${N} Start Docker Desktop and try again."; exit 2
  fi
}

summary() {
  echo
  if [ "$FAILED" -eq 0 ]; then
    echo "${G}${B}All $PASSED checks passed.${N} Nice work. 🎉"; exit 0
  else
    echo "${B}$PASSED passed, ${R}$FAILED failed.${N} Fix the ✘ items and run the check again."; exit 1
  fi
}

# Warn (don't fail) if a host port is already taken by something outside this lab.
# Usage: port_owner_warning PORT COMPOSE_PROJECT
port_owner_warning() {
  local port="$1" project="${2:-}"
  local who
  who=$(docker ps --format '{{.Names}} {{.Ports}}' | grep -E "[:.]$port->" | grep -v "^$project" | awk '{print $1}')
  if [ -n "$who" ]; then
    echo "  ${Y}!${N} port $port is already used by container '$who'. Stop it first (docker stop $who)"
  elif lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1 && ! docker ps --format '{{.Names}} {{.Ports}}' | grep -qE "^$project.*[:.]$port->"; then
    echo "  ${Y}!${N} port $port is already in use by another program (lsof -iTCP:$port -sTCP:LISTEN)"
  fi
}
