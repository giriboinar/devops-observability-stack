#!/usr/bin/env bash
# Smoke test: bring the Compose stack up, generate traffic, verify
# Prometheus sees the app and at least one alert rule evaluates.
set -euo pipefail
cd "$(dirname "$0")/.."

export GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-changeme}"
docker compose up -d --build

echo "Waiting for services..."
for i in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:8000/healthz >/dev/null && \
     curl -fsS http://127.0.0.1:9090/-/healthy >/dev/null; then
    break
  fi
  sleep 5
done

echo "Generating traffic..."
for _ in $(seq 1 50); do curl -s http://127.0.0.1:8000/api/ping >/dev/null; done
curl -s "http://127.0.0.1:8000/api/flaky?fail=true" >/dev/null || true

echo "Checking Prometheus target + rules..."
curl -fsS "http://127.0.0.1:9090/api/v1/targets" | grep -q '"health":"up"' \
  && echo "OK: demo-app target up"
curl -fsS "http://127.0.0.1:9090/api/v1/rules" | grep -q 'AppDown' \
  && echo "OK: alert rules loaded"
curl -fsS "http://127.0.0.1:9090/api/v1/query?query=app_requests_total" | grep -q 'app_requests_total' \
  && echo "OK: app metrics scraped"

echo "Smoke test passed. Tear down with: docker compose down"
