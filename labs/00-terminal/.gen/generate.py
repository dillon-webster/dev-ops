"""Regenerates the lab's data files. Deterministic (fixed seed). You don't need to run this."""
import random
from datetime import datetime, timedelta
from pathlib import Path

random.seed(1337)
ROOT = Path(__file__).resolve().parent.parent / "data"

ips = [f"10.0.{random.randint(0, 9)}.{random.randint(2, 250)}" for _ in range(40)]
heavy = "10.0.7.66"  # the noisy client
paths = ["/", "/login", "/api/users", "/api/orders", "/api/cart", "/static/app.js",
         "/static/style.css", "/search", "/api/products", "/checkout"]
agents = ["Mozilla/5.0 (Macintosh)", "Mozilla/5.0 (Windows NT 10.0)", "curl/8.4.0",
          "kube-probe/1.30", "Mozilla/5.0 (iPhone)"]

start = datetime(2026, 9, 14, 0, 0, 0)
lines = []
t = start
for i in range(4812):
    t += timedelta(seconds=random.randint(1, 30))
    agent = random.choice(agents)
    if agent == "kube-probe/1.30":
        ip, path, status = "10.0.0.1", "/health", 200
    else:
        ip = heavy if random.random() < 0.09 else random.choice(ips)
        path = random.choice(paths)
        r = random.random()
        status = 200 if r < 0.86 else 404 if r < 0.93 else 500 if r < 0.97 else 302
        if status == 404 and random.random() < 0.55:
            path = "/wp-admin.php"
    size = random.randint(120, 9000)
    ts = t.strftime("%d/%b/%Y:%H:%M:%S +0000")
    lines.append(f'{ip} - - [{ts}] "GET {path} HTTP/1.1" {status} {size} "-" "{agent}"')

(ROOT / "nginx").mkdir(parents=True, exist_ok=True)
(ROOT / "nginx" / "access.log").write_text("\n".join(lines) + "\n")

# App logs spread over services and days.
levels = ["INFO"] * 20 + ["WARN"] * 3 + ["ERROR"] * 2 + ["DEBUG"] * 4
msgs = {
    "INFO": ["request completed", "cache hit", "user logged in", "job finished", "connected to db"],
    "WARN": ["slow query took 2300ms", "retrying request", "cache miss storm"],
    "ERROR": ["failed to charge card", "connection refused: db:5432", "timeout calling inventory"],
    "DEBUG": ["payload parsed", "headers ok", "span started"],
}
services = ["api", "billing", "worker"]
for svc in services:
    for day in (14, 15, 16):
        d = ROOT / "app" / svc
        d.mkdir(parents=True, exist_ok=True)
        out = []
        tt = datetime(2026, 9, day, 0, 0, 0)
        for _ in range(random.randint(300, 500)):
            tt += timedelta(seconds=random.randint(10, 200))
            lvl = random.choice(levels)
            # Some services log lowercase levels. Real life is messy.
            shown = lvl.lower() if svc == "worker" and random.random() < 0.5 else lvl
            out.append(f"{tt.isoformat()} [{shown}] {svc}: {random.choice(msgs[lvl])}")
        if svc == "billing" and day == 15:
            out.insert(211, f"2026-09-15T09:41:07 [ERROR] billing: java.lang.OutOfMemoryError: Java heap space")
        (d / f"{svc}-2026-09-{day}.log").write_text("\n".join(out) + "\n")
# A rotated/compressed-looking file that should NOT count as .log
(ROOT / "app" / "api" / "api-2026-09-13.log.gz.txt").write_text("old rotated file\n")

# Configs
envs = {"dev": (5432, 20), "staging": (5433, 100), "prod": (6432, 400)}
for env, (port, maxc) in envs.items():
    d = ROOT / "config" / env
    d.mkdir(parents=True, exist_ok=True)
    (d / "db.conf").write_text(
        f"# database settings for {env}\nhost = db.{env}.internal\nport = {port}\n"
        f"max_connections = {maxc}\n# max_connections = 9999  (old value, ignore)\nssl = {'on' if env == 'prod' else 'off'}\n"
    )
    (d / "app.conf").write_text(f"log_level = {'debug' if env == 'dev' else 'info'}\nworkers = {4 if env == 'prod' else 1}\n")
(ROOT / "config" / "staging" / "secrets.conf").write_text("# TODO: move to vault!!\napi_token = tok_9f8e7d6c\n")
