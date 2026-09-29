#!/usr/bin/env bash
# Restore a backup made by backup.sh into a Docker volume.
#
# Usage: ./restore.sh ARCHIVE VOLUME
#
# The volume is created if it doesn't exist. Anything already in it is REPLACED.

# TODO: strict mode, check both args, check ARCHIVE exists (exit 1 with a message if not),
#       then use a throwaway alpine container to empty the volume and extract ARCHIVE into it.
