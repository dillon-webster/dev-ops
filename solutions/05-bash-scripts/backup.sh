#!/usr/bin/env bash
# Back up a Docker volume to a timestamped .tar.gz, keeping only the newest $KEEP backups.
#
# Usage: ./backup.sh VOLUME [DEST_DIR]
#   DEST_DIR defaults to ./backups
#   KEEP     (env var) defaults to 5
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 VOLUME [DEST_DIR]   (env: KEEP=5)" >&2
  exit 1
fi

VOLUME="$1"
DEST_DIR="${2:-./backups}"
KEEP="${KEEP:-5}"

if ! docker volume inspect "$VOLUME" >/dev/null 2>&1; then
  echo "error: no such volume: $VOLUME" >&2
  exit 1
fi

mkdir -p "$DEST_DIR"
DEST_DIR="$(cd "$DEST_DIR" && pwd)"

FILE="$VOLUME-$(date +%Y%m%d-%H%M%S).tar.gz"

docker run --rm \
  -v "$VOLUME:/data:ro" \
  -v "$DEST_DIR:/backup" \
  alpine tar czf "/backup/$FILE" -C /data .

# Timestamps sort as text, so newest-first is a reverse sort. Skip the first $KEEP, delete the rest.
find "$DEST_DIR" -maxdepth 1 -name "$VOLUME-*.tar.gz" | sort -r | tail -n +$((KEEP + 1)) |
  while read -r old; do
    rm -- "$old"
  done

echo "$DEST_DIR/$FILE"
