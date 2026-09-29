# Lab 05: Bash automation (backups)

**Time:** 1–2 hours · **Needs:** Lab 00 (terminal), Lab 03 (volumes) · **You'll learn:** writing real shell scripts: arguments, defaults, error handling, exit codes, `$( )`, loops, and running Docker from scripts

## The situation

Our Redis data lives in a Docker volume. Right now there are no backups at all, which means one accidental `docker compose down -v` and it's gone. Write two scripts:

- `backup.sh VOLUME [DEST_DIR]` saves a volume to `DEST_DIR/VOLUME-YYYYmmdd-HHMMSS.tar.gz` and keeps only the newest `KEEP` backups (default 5).
- `restore.sh ARCHIVE VOLUME` puts a backup back into a volume.

Both files have `TODO` comments that walk you through it step by step.

## Bash crash course

```bash
#!/usr/bin/env bash        # first line: "run me with bash"
set -euo pipefail          # -e stop on any error, -u error on unset variables, pipefail: a failing command in a pipe counts as a failure

echo "$1"                  # first argument ($2 second, $# how many, $@ all of them)
NAME="${1:-default}"       # $1, or "default" if it's missing
KEEP="${KEEP:-5}"          # env var with a default
NOW="$(date +%Y%m%d-%H%M%S)"   # $( ) captures a command's output

if [ $# -lt 1 ]; then      # spaces inside [ ] are required!
  echo "usage: $0 VOLUME" >&2   # >&2 sends it to stderr, where errors belong
  exit 1                        # non-zero exit = failure
fi

if ! docker volume inspect "$NAME" >/dev/null 2>&1; then   # hide output, use only the exit code
  echo "no such volume: $NAME" >&2; exit 1
fi

for f in *.tar.gz; do echo "$f"; done
```

**Always quote your variables** (`"$VOLUME"`, not `$VOLUME`). Unquoted variables break on spaces and are the #1 source of bash bugs.

Check your syntax as you go with **ShellCheck**, the linter every bash writer should use:

```bash
docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:stable backup.sh restore.sh
```

## Backing up a volume with Docker

You can't easily reach a volume's files from your Mac, but any container can mount it. The trick is a throwaway container:

```bash
docker run --rm \
  -v MYVOLUME:/data:ro \
  -v "/absolute/path/to/backups:/backup" \
  alpine tar czf /backup/NAME.tar.gz -C /data .
```

`tar czf` means **c**reate, g**z**ip, **f**ile. `-C /data .` means "go into /data and archive everything there".

## Try it on real data

```bash
cd ~/Code/devops-practice/labs/03-compose && docker compose up -d   # needs Lab 03 done
curl localhost:8300/; curl localhost:8300/                          # make some visits
cd ../05-bash-scripts
docker volume ls                                                    # find the volume name
./backup.sh devops-lab03_redis-data
ls -lh backups/
```

Then try a disaster drill: `docker compose down -v` in lab 03 (the data is gone!), then `./restore.sh backups/<file> devops-lab03_redis-data`, `docker compose up -d`, and curl. Is the count back?

## Grade it

```bash
./check.sh
```

The checker uses its own throwaway test volumes, so it won't touch your real data.

## Hints

<details><summary>Getting an absolute path</summary>

Docker `-v` needs an absolute path. `mkdir -p "$DEST_DIR"` and then `DEST_DIR="$(cd "$DEST_DIR" && pwd)"`.
</details>

<details><summary>Keeping only the newest N files</summary>

Because the timestamp format sorts correctly as text, the newest files sort *last*:

```bash
ls -1 "$DEST_DIR"/"$VOLUME"-*.tar.gz | sort | head -n -"$KEEP"
```

…except macOS `head` doesn't support negative numbers. 😅 Reverse it instead: `sort -r | tail -n +$((KEEP + 1))` gives you everything *after* the newest KEEP. Pipe that into a `while read -r f; do rm -- "$f"; done` loop.
</details>

<details><summary>Restoring</summary>

```bash
docker run --rm -v "$VOLUME:/data" -v "$ARCHIVE_DIR:/backup:ro" alpine \
  sh -c 'rm -rf /data/* /data/..?* /data/.[!.]* ; tar xzf /backup/FILE -C /data'
```

You'll need the archive's directory (`dirname`) and file name (`basename`) separately.
</details>

## Stretch goals

- Schedule it: run `crontab -e` and add `0 3 * * * /full/path/backup.sh devops-lab03_redis-data /full/path/backups >> /tmp/backup.log 2>&1`. (On your home server this is how you'd back up Vaultwarden!)
- Add a `--dry-run` flag that prints what it *would* delete.
- Verify each backup after writing it (`tar tzf` lists the contents without extracting).
