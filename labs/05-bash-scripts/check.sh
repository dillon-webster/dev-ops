#!/usr/bin/env bash
source "$(dirname "$0")/../lib.sh"
require_docker
LAB="$REPO_ROOT/labs/05-bash-scripts"
VOL=lab05-check-src
VOL2=lab05-check-restore
TMP=$(mktemp -d)
cleanup() { docker volume rm -f "$VOL" "$VOL2" >/dev/null 2>&1; rm -rf "$TMP"; }
trap cleanup EXIT
cleanup; TMP=$(mktemp -d)

title "Lab 05: Bash automation"

check "backup.sh and restore.sh are executable" "chmod +x backup.sh restore.sh" \
  test -x "$LAB/backup.sh" -a -x "$LAB/restore.sh"

sc=$(docker run --rm -v "$LAB:/mnt" koalaman/shellcheck:stable backup.sh restore.sh 2>&1)
if [ -z "$sc" ]; then pass "shellcheck is clean"; else
  fail "shellcheck is clean" "run shellcheck (see README) and fix each warning"; echo "$sc" | head -20 | sed 's/^/      /'; fi

check "backup.sh uses strict mode (set -euo pipefail)" "add: set -euo pipefail" \
  grep -qE '^set -[a-z]*e[a-z]*u[a-z]*o pipefail|^set -euo pipefail' "$LAB/backup.sh"

check "backup.sh with no arguments exits non-zero" "check \$# and exit 1" \
  sh -c "! '$LAB/backup.sh' >/dev/null 2>&1"
out=$("$LAB/backup.sh" 2>&1 >/dev/null)
check "...and prints usage to stderr" "echo \"usage: ...\" >&2" test -n "$out"

check "backup.sh on a missing volume exits non-zero" "docker volume inspect fails for missing volumes" \
  sh -c "! '$LAB/backup.sh' lab05-definitely-missing '$TMP/x' >/dev/null 2>&1"

# Seed a test volume
docker volume create "$VOL" >/dev/null
docker run --rm -v "$VOL:/data" alpine sh -c 'echo "precious data" > /data/important.txt; mkdir -p /data/sub; echo 42 > /data/sub/answer; echo hidden > /data/.dotfile' >/dev/null

mkdir -p "$TMP/work"
path=$(cd "$TMP/work" && "$LAB/backup.sh" "$VOL" 2>/dev/null | tail -n 1)
check "backup.sh defaults DEST_DIR to ./backups" "DEST_DIR=\"\${2:-./backups}\"" \
  sh -c "ls '$TMP/work/backups/'$VOL-*.tar.gz"

"$LAB/backup.sh" "$VOL" "$TMP/b" >/dev/null 2>&1
f=$(ls "$TMP"/b/$VOL-*.tar.gz 2>/dev/null | head -1)
check "file is named VOLUME-YYYYmmdd-HHMMSS.tar.gz" "date +%Y%m%d-%H%M%S" \
  sh -c "basename '$f' | grep -qE '^$VOL-[0-9]{8}-[0-9]{6}\.tar\.gz$'"
check "archive contains the volume's files (incl. subfolders and dotfiles)" "tar czf ... -C /data ." \
  sh -c "[ -n '$f' ] && tar tzf '$f' | grep -q important.txt && tar tzf '$f' | grep -q sub/answer && tar tzf '$f' | grep -q .dotfile"
check "backup.sh prints the backup's path" "echo the path at the end" \
  sh -c "[ -n '$path' ] && ls '$TMP/work/'\"\$(basename '$path')\" 2>/dev/null || ls '$path'"

info "running backup 6 more times with KEEP=3 (takes ~7s, timestamps need different seconds)..."
mkdir -p "$TMP/b"; touch "$TMP/b/other-volume-20200101-000000.tar.gz"
for _ in 1 2 3 4 5 6; do sleep 1.1; KEEP=3 "$LAB/backup.sh" "$VOL" "$TMP/b" >/dev/null 2>&1; done
n=$(ls "$TMP"/b/$VOL-*.tar.gz 2>/dev/null | wc -l | tr -d ' ')
check "KEEP=3 leaves exactly 3 backups (found $n)" "sort, skip the newest KEEP, delete the rest" test "$n" = 3
newest_kept=$(ls "$TMP"/b/$VOL-*.tar.gz 2>/dev/null | sort | tail -1)
check "the newest backups are the ones kept" "make sure you delete the OLDEST ones" \
  sh -c "[ -n '$f' ] && ! ls '$f' 2>/dev/null && [ -f '$newest_kept' ]"
check "other volumes' backups are left alone" "only prune files starting with \$VOLUME-" \
  test -f "$TMP/b/other-volume-20200101-000000.tar.gz"

check "restore.sh with a missing archive exits non-zero" "test -f \"\$ARCHIVE\" || exit 1" \
  sh -c "! '$LAB/restore.sh' '$TMP/nope.tar.gz' '$VOL2' >/dev/null 2>&1"

docker volume create "$VOL2" >/dev/null
docker run --rm -v "$VOL2:/data" alpine sh -c 'echo junk > /data/stale.txt' >/dev/null
"$LAB/restore.sh" "$newest_kept" "$VOL2" >/dev/null 2>&1
restored=$(docker run --rm -v "$VOL2:/data:ro" alpine sh -c 'cat /data/important.txt /data/sub/answer; ls -a /data' 2>/dev/null)
check "restore.sh brings the data back" "tar xzf into the mounted volume" \
  sh -c "grep -q 'precious data' <<<\"\$0\" && grep -qx 42 <<<\"\$0\" && grep -q .dotfile <<<\"\$0\"" "$restored"
check "restore.sh replaces what was there before" "empty the volume before extracting" \
  sh -c "! grep -q stale.txt <<<\"\$0\"" "$restored"

docker volume rm -f "$VOL2" >/dev/null
"$LAB/restore.sh" "$newest_kept" "$VOL2" >/dev/null 2>&1
check "restore.sh works when the volume doesn't exist yet" "docker run -v NAME:/data creates it automatically" \
  sh -c "docker run --rm -v '$VOL2:/data:ro' alpine cat /data/important.txt | grep -q precious"

summary
