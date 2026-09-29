# Lab 07: Monitoring with Prometheus and Grafana

**Time:** 1–2 hours · **You'll learn:** metrics, scraping, PromQL, alert rules, Grafana data sources and dashboards

## The idea

Logs tell you *what happened*. **Metrics** tell you *how much, how often, how fast* over time. In this stack:

- The app exposes counters at http://localhost:8700/metrics (open it and look, it's just text).
- **Prometheus** *pulls* ("scrapes") that page every few seconds and stores the numbers as time series.
- **Alert rules** are PromQL queries Prometheus checks continuously ("is the app down?").
- **Grafana** draws graphs from Prometheus.

A special metric, `up`, is created by Prometheus for every target: `1` if the last scrape worked, `0` if it didn't.

## Start the stack

```bash
cd ~/Code/devops-practice/labs/07-observability
docker compose up -d --build
```

| What | URL |
|---|---|
| App | http://localhost:8700 |
| Prometheus | http://localhost:9700 (check **Status → Target health**) |
| Grafana | http://localhost:3700 |

After editing Prometheus config, reload it with `docker compose restart prometheus`. After editing Grafana provisioning, use `docker compose restart grafana`.

## Your tasks

### 1. Scrape the app
In `prometheus/prometheus.yml`, add a scrape job named **`app`** that scrapes the web service. Remember Lab 03: containers find each other by *service name*, and you want the port the app listens on *inside* its container, not the one published to your Mac. When it works, the `app` target shows **UP** under Status → Target health.

### 2. Make some traffic and query it
Generate load with a bash loop:

```bash
for i in $(seq 1 200); do curl -s localhost:8700/ >/dev/null; done
```

Then run these in the Prometheus **Query** tab (use the Graph view) and make sure you understand each one:

```promql
up
app_requests_total
rate(app_requests_total[1m])          # requests per second, averaged over 1 minute
sum by (endpoint) (rate(app_requests_total[1m]))
```

Run the loop again while watching the graph. Try `while true; do curl -s localhost:8700/ >/dev/null; sleep 0.2; done` (Ctrl-C to stop).

### 3. Alert when the app is down
In `prometheus/alerts.yml`, write an alert named **`AppDown`** that fires when the `app` job's `up` metric is `0`. Give it:
- `for: 15s` (it must stay down for 15 seconds before it fires, so you don't get paged for a blip)
- a label `severity: critical`
- an annotation `summary` explaining what's wrong

Test it with `docker compose stop web`, then watch the **Alerts** page: *inactive → pending → firing*. Run `docker compose start web` when done.

### 4. Connect Grafana
Create `grafana/provisioning/datasources/prometheus.yml` so that Grafana automatically has a Prometheus data source named **`Prometheus`** pointing at the Prometheus container. This is "config as code": no clicking around a UI, so the setup is reproducible.

Then, in Grafana (http://localhost:3700): **Dashboards → New → Add visualization**, pick Prometheus, and graph `sum(rate(app_requests_total[1m]))`. Save it.

## Grade it

```bash
./check.sh
```

This stops `web` for a bit to test your alert, then starts it again.

## Hints

<details><summary>Scrape job</summary>

```yaml
  - job_name: app
    static_configs:
      - targets: ["SERVICE:PORT"]
```

Prometheus assumes the path is `/metrics`, which is what our app uses.
</details>

<details><summary>Alert rule shape</summary>

```yaml
groups:
  - name: app
    rules:
      - alert: AppDown
        expr: up{job="app"} == 0
        for: 15s
        labels:
          severity: ...
        annotations:
          summary: ...
```

Validate your files without restarting anything: `docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml`
</details>

<details><summary>Grafana data source file</summary>

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://???:9090
    isDefault: true
```
</details>

## Stretch goals

- Export your Grafana dashboard as JSON (Share → Export) and provision it from `grafana/provisioning/dashboards/`, so it's also config as code.
- Add **cAdvisor** or **node-exporter** to see container CPU and memory.
- Add a `HighErrorRate` alert. (You'd need an error counter in the app first. Try adding one!)
- Add Alertmanager and route `critical` alerts to a Discord or ntfy webhook. Then point it at your home server.
