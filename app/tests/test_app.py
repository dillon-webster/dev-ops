import os
from unittest import mock

import pytest
import redis

os.environ.setdefault("REDIS_HOST", "localhost")

import app as app_module  # noqa: E402


@pytest.fixture
def client():
    return app_module.app.test_client()


def test_health_does_not_need_redis(client):
    assert client.get("/health").status_code == 200


def test_index_counts_visits(client):
    with mock.patch.object(app_module.store, "incr", return_value=42):
        body = client.get("/").get_json()
    assert body["visits"] == 42


def test_ready_reports_redis_outage(client):
    with mock.patch.object(app_module.store, "ping", side_effect=redis.ConnectionError("down")):
        assert client.get("/ready").status_code == 503


def test_metrics_exposed(client):
    client.get("/health")
    assert b"app_requests_total" in client.get("/metrics").data
