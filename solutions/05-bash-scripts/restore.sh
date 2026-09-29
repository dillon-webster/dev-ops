#!/usr/bin/env bash
# Restore a backup made by backup.sh into a Docker volume.
#
# Usage: ./restore.sh ARCHIVE VOLUME
#
# The volume is created if it doesn't exist. Anything already in it is REPLACED.
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "usage: $0 ARCHIVE VOLUME" >&2
  exit 1
fi

ARCHIVE="$1"
VOLUME="$2"

if [ ! -f "$ARCHIVE" ]; then
  echo "error: archive not found: $ARCHIVE" >&2
  exit 1
fi

ARCHIVE_DIR="$(cd "$(dirname "$ARCHIVE")" && pwd)"
ARCHIVE_FILE="$(basename "$ARCHIVE")"

# Globs cover normal files, dotfiles, and names starting with "..".
docker run --rm \
  -v "$VOLUME:/data" \
  -v "$ARCHIVE_DIR:/backup:ro" \
  alpine sh -c "rm -rf /data/* /data/.[!.]* /data/..?*; tar xzf \"/backup/$ARCHIVE_FILE\" -C /data"

echo "restored $ARCHIVE_FILE into volume $VOLUME"
