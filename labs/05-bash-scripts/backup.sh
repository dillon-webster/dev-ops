#!/usr/bin/env bash
# Back up a Docker volume to a timestamped .tar.gz, keeping only the newest $KEEP backups.
#
# Usage: ./backup.sh VOLUME [DEST_DIR]
#   DEST_DIR defaults to ./backups
#   KEEP     (env var) defaults to 5
#
# Example: KEEP=3 ./backup.sh devops-lab03_redis-data ~/backups

# TODO 1: make the script stop on errors, unset variables, and failed pipes.

# TODO 2: if no VOLUME argument was given, print the usage to stderr and exit 1.

# TODO 3: set VOLUME, DEST_DIR (default ./backups) and KEEP (default 5).

# TODO 4: if the volume doesn't exist, print an error to stderr and exit 1.
#         (hint: `docker volume inspect NAME` fails when it doesn't exist)

# TODO 5: make DEST_DIR (and its parents) if needed, then get its absolute path.

# TODO 6: build the file name: VOLUME-YYYYmmdd-HHMMSS.tar.gz

# TODO 7: run a throwaway alpine container that mounts the volume (read-only) and
#         DEST_DIR, and tars the volume's contents into DEST_DIR.

# TODO 8: delete all but the newest $KEEP backups for THIS volume.

# TODO 9: print the path of the new backup.
