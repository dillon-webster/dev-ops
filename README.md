# DevOps practice labs

Hands-on labs that build on each other. Every lab has:

- a **README.md** that explains the idea, the task, and hints you can expand when stuck
- broken or unfinished files for you to fix
- a **check.sh** grader. Run it as often as you like; it tells you what's still wrong

Everything runs locally on Docker. No cloud account needed.

| # | Lab | You'll learn |
|---|---|---|
| 00 | [Terminal detective](labs/00-terminal/README.md) | `grep`, `find`, pipes, `sort \| uniq -c`, `awk`, `head`/`tail`, `less` |
| 01 | [Docker basics](labs/01-docker-basics/README.md) | images vs containers, ports, bind mounts, `logs`, `exec` |
| 02 | [Fix a bad Dockerfile](labs/02-dockerfile/README.md) | layer caching, `.dockerignore`, non-root, secrets, healthchecks |
| 03 | [Docker Compose](labs/03-compose/README.md) | multi-container apps, service DNS, volumes, `depends_on`, `.env` |
| 04 | [Incident: the site is down](labs/04-incident/README.md) | debugging hop by hop, reading logs, writing a postmortem |
| 05 | [Bash automation](labs/05-bash-scripts/README.md) | real scripts: args, defaults, exit codes, backup & restore |
| 06 | [Continuous Integration](labs/06-ci/README.md) | venvs, Makefiles, lint/test, GitHub Actions |
| 07 | [Monitoring](labs/07-observability/README.md) | Prometheus, PromQL, alerts, Grafana |

Do them **in order**. Labs 03, 04, and 07 build the app with your Dockerfile from Lab 02.

## Before you start

1. Make sure Docker Desktop is running: `docker info` should not error.
2. Turn this folder into a git repo so you can see and undo your own changes. This is good practice anyway:

   ```bash
   cd ~/Code/devops-practice
   git init && git add -A && git commit -m "starting point"
   ```

   Then use `git status` and `git diff` to see what you changed, and `git restore <file>` to undo a mess.

## The app

`app/` is a tiny Python (Flask) visit counter backed by Redis:

| Endpoint | What it does |
|---|---|
| `/` | increments and returns the visit count |
| `/health` | "the process is alive" (doesn't touch Redis) |
| `/ready` | "I can actually serve traffic" (pings Redis) |
| `/metrics` | Prometheus metrics |

## Ports used

| Lab | Ports |
|---|---|
| 01 | 8090 |
| 02 | 8000 (the checker uses 18000) |
| 03 | 8300 |
| 04 | 8400 |
| 07 | 8700 (app), 9700 (Prometheus), 3700 (Grafana) |

8080 was avoided on purpose, because your `frontend` container already uses it.

## Stuck?

1. Read the error message. The **last** line is usually the most useful one.
2. Open the hints in the lab README, one at a time.
3. `solutions/` has reference answers. Try hard before peeking. Being stuck and getting unstuck is the actual skill you're practicing.

## Cleaning up

Each lab README ends with its own cleanup. To nuke everything:

```bash
for d in labs/0{3,4,7}*/; do (cd "$d" && docker compose down -v); done
docker rm -f lab01-web 2>/dev/null
```

## Where to go next

- **Kubernetes:** `brew install kind`, then run this same app with Deployments, Services, probes (`/health` and `/ready` exist for exactly this), ConfigMaps, and Secrets.
- **Terraform:** provision something real (a DigitalOcean droplet, or a Cloudflare DNS record).
- **Ansible:** automate setting up your home server so you could rebuild it from scratch.
- **Your home server:** put Lab 07's Prometheus + Grafana on it and monitor your Minecraft, Jellyfin, and Vaultwarden containers. Use Lab 05's script to back up Vaultwarden's volume every night.
