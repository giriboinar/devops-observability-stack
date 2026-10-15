"""Tests for the instrumented demo API."""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_index():
    r = client.get("/")
    assert r.status_code == 200
    body = r.json()
    assert body["app"] == "demo-app"
    assert body["metrics"] == "/metrics"


def test_healthz_and_readyz():
    assert client.get("/healthz").json() == {"status": "ok"}
    assert client.get("/readyz").json() == {"status": "ready"}


def test_ping():
    r = client.get("/api/ping")
    assert r.status_code == 200
    assert r.json()["message"] == "pong"


def test_slow_returns_latency_field():
    r = client.get("/api/slow", params={"max_ms": 10})
    assert r.status_code == 200
    assert r.json()["slept_seconds"] >= 0


def test_flaky_ok_and_fail():
    assert client.get("/api/flaky").status_code == 200
    r = client.get("/api/flaky", params={"fail": "true"})
    assert r.status_code == 500
    assert r.json()["error"] == "simulated failure"


def test_metrics_endpoint_exposes_app_metrics():
    # Generate some traffic first so counters/histograms have samples.
    client.get("/api/ping")
    client.get("/api/slow", params={"max_ms": 5})
    r = client.get("/metrics")
    assert r.status_code == 200
    assert "text/plain" in r.headers["content-type"]
    body = r.text
    assert "app_requests_total" in body
    assert "app_request_duration_seconds_bucket" in body
    assert 'app_build_info{name="demo-app",version="1.0.0"} 1.0' in body


def test_unknown_route_is_404():
    assert client.get("/nope").status_code == 404
