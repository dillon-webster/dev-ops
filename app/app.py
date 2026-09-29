"""Tiny visit-counter service used by every lab."""
import os
import sys
import socket

import redis
from flask import Flask, Response, jsonify
from prometheus_client import CONTENT_TYPE_LATEST, Counter, generate_latest

app = Flask(__name__)

# REDIS_HOST is required on purpose: a missing value should fail loudly at startup.
REDIS_HOST = os.environ["REDIS_HOST"]
store = redis.Redis(
    host=REDIS_HOST,
    port=int(os.environ.get("REDIS_PORT", "6379")),
    password=os.environ.get("REDIS_PASSWORD") or None,
    socket_connect_timeout=2,
    socket_timeout=2,
)

REQUESTS = Counter("app_requests_total", "Requests served", ["endpoint"])


@app.get("/")
def index():
    REQUESTS.labels("/").inc()
    visits = store.incr("visits")
    return jsonify(
        message=os.environ.get("GREETING", "hello"),
        visits=visits,
        host=socket.gethostname(),
    )


@app.get("/health")
def health():
    """Liveness: the process is up. Deliberately does not touch Redis."""
    return jsonify(status="ok")


@app.get("/ready")
def ready():
    """Readiness: we can actually serve traffic."""
    try:
        store.ping()
    except redis.RedisError as exc:
        return jsonify(status="unavailable", error=str(exc)), 503
    return jsonify(status="ready")


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)


if __name__ == "__main__":
    # Dev server only. In a container, run: gunicorn -b 0.0.0.0:8000 app:app
    app.run(host="0.0.0.0", port=5000, debug=True)
