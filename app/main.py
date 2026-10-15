"""Demo API instrumented with Prometheus metrics.

A small FastAPI service used as the scrape target for the observability
stack. Every request is timed and counted so the Prometheus/Grafana/
Alertmanager pipeline has real RED metrics (Rate, Errors, Duration) to work
with. No secrets, no external dependencies.
"""

from __future__ import annotations

import random
import time
from typing import Callable

from fastapi import FastAPI, Request, Response
from fastapi.responses import JSONResponse, PlainTextResponse
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, Info, generate_latest

APP_NAME = "demo-app"
APP_VERSION = "1.0.0"

REQUEST_COUNT = Counter(
    "app_requests_total",
    "Total HTTP requests handled by the demo app",
    ["method", "endpoint", "status"],
)
REQUEST_LATENCY = Histogram(
    "app_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "endpoint"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5),
)
APP_INFO = Info("app_build", "Build information for the demo app")
APP_INFO.info({"name": APP_NAME, "version": APP_VERSION})

app = FastAPI(title=APP_NAME, version=APP_VERSION)


@app.middleware("http")
async def observe_requests(request: Request, call_next: Callable) -> Response:
    start = time.perf_counter()
    response = await call_next(request)
    elapsed = time.perf_counter() - start
    # Keep cardinality bounded: collapse to the route path template where possible.
    endpoint = request.scope.get("route").path if request.scope.get("route") else request.url.path
    REQUEST_LATENCY.labels(request.method, endpoint).observe(elapsed)
    REQUEST_COUNT.labels(request.method, endpoint, response.status_code).inc()
    return response


@app.get("/", summary="Service index")
def index() -> dict:
    return {"app": APP_NAME, "version": APP_VERSION, "docs": "/docs", "metrics": "/metrics"}


@app.get("/healthz", summary="Liveness probe")
def healthz() -> dict:
    return {"status": "ok"}


@app.get("/readyz", summary="Readiness probe")
def readyz() -> dict:
    return {"status": "ready"}


@app.get("/api/ping", summary="Simple ping endpoint")
def ping() -> dict:
    return {"message": "pong", "app": APP_NAME}


@app.get("/api/slow", summary="Endpoint with simulated latency")
def slow(max_ms: int = 300) -> dict:
    """Sleeps a random 0..max_ms so the latency histogram has spread."""
    delay = random.uniform(0, max(0, max_ms)) / 1000.0
    time.sleep(delay)
    return {"slept_seconds": round(delay, 3)}


@app.get("/api/flaky", summary="Endpoint that fails on demand")
def flaky(fail: bool = False) -> Response:
    """Pass ?fail=true to generate 5xx traffic for alerting demos."""
    if fail:
        return JSONResponse(status_code=500, content={"error": "simulated failure"})
    return JSONResponse(status_code=200, content={"status": "ok"})


@app.get("/metrics", summary="Prometheus scrape endpoint")
def metrics() -> PlainTextResponse:
    return PlainTextResponse(generate_latest(), media_type=CONTENT_TYPE_LATEST)
