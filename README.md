# devops-observability-stack

A production-style observability stack for an instrumented demo API:
**demo-app (FastAPI + Prometheus metrics) → Prometheus → Alertmanager →
Grafana**, runnable via Docker Compose, packaged as a Helm chart for
Kubernetes, and deployable to an AWS Free Tier host with Terraform.

## Why this exists

SRE/DevOps roles consistently ask for Prometheus/Grafana/Alertmanager,
SLI/SLO alerting, and Helm packaging. This repo is a working, demoable
answer: real RED metrics (rate/errors/duration), real alert rules with a
routing tree, and a CI pipeline that validates every config with the
official tools (`promtool`, `amtool`) before anything ships.

## Repo layout

```
app/                    FastAPI demo API, instrumented with prometheus_client
tests/                  pytest suite for the API
Dockerfile              multi-stage, pinned base, non-root, HEALTHCHECK
docker-compose.yml      full stack: app, prometheus, alertmanager, grafana, node-exporter
monitoring/
  prometheus/           prometheus.yml + alerts.yml (AppDown, HighErrorRate, HighLatencyP95, HostHighCPU)
  alertmanager/         alertmanager.yml (grouping/routing; webhook placeholder)
  grafana/              provisioned Prometheus datasource + "demo-app overview" dashboard
helm/observability-stack  Kubernetes chart (hardened pods: non-root, dropped caps, seccomp, limits)
terraform/              AWS Free Tier t3.micro host running the Compose stack (manual apply only)
.github/workflows/     ci.yml (test→validate→lint→build→Trivy→Docker Hub) + cd.yml (manual EC2 deploy)
scripts/smoke-test.sh   end-to-end smoke test for the Compose stack
docs/architecture.md    component diagram, alert flow, CI/CD description
```

## Prerequisites

- Docker Engine 24+ with the Compose plugin (for the Compose path)
- Python 3.12 + pip (for running tests locally)
- Helm 3.12+ (for the Kubernetes path)
- Terraform 1.9+ and AWS credentials (for the AWS path, optional)

## Quickstart (Docker Compose)

```bash
git clone https://github.com/giriboinar/devops-observability-stack.git
cd devops-observability-stack
export GRAFANA_ADMIN_PASSWORD='a-strong-password'   # never commit real values
docker compose up -d --build
```

| Service      | URL                   | Notes                              |
|--------------|-----------------------|------------------------------------|
| demo-app     | http://localhost:8000 | `/docs`, `/metrics`, `/healthz`    |
| Prometheus   | http://localhost:9090 | targets, rules, PromQL             |
| Alertmanager | http://localhost:9093 | alert grouping/routing             |
| Grafana      | http://localhost:3000 | login `admin` / your password      |

Generate traffic and watch the dashboard move:

```bash
for i in $(seq 1 100); do curl -s localhost:8000/api/ping >/dev/null; done
curl -s "localhost:8000/api/flaky?fail=true" >/dev/null   # 5xx traffic -> HighErrorRate
```

Tear down: `docker compose down -v`

## Run the tests

```bash
pip install -r app/requirements.txt
python -m pytest tests/ -q
```

## Docker image (demo-app)

```bash
docker build -t demo-app:local .
docker run --rm -p 8000:8000 demo-app:local
```

Multi-stage build, `python:3.12-slim-bookworm` pinned (verified on Docker Hub),
runtime runs as non-root `appuser`, `/healthz` HEALTHCHECK, no secrets baked in.

## Kubernetes (Helm)

```bash
helm lint helm/observability-stack
helm install obs helm/observability-stack --set grafana.adminPassword='a-strong-password'
kubectl port-forward svc/obs-grafana 3000
```

## AWS (Terraform, Free Tier only)

```bash
cd terraform
terraform init
terraform plan -var="ssh_allowed_cidr=<YOUR_IP>/32" -var="grafana_admin_password=<STRONG>"
# review the plan, then only with approval:
terraform apply -var="ssh_allowed_cidr=<YOUR_IP>/32" -var="grafana_admin_password=<STRONG>"
```

Provisions a `t3.micro` in the default VPC; user-data installs Docker and
starts the Compose stack. `terraform destroy` when done.

## CI/CD

- **ci.yml** (on push/PR to `main`): pytest → `docker compose config` →
  `promtool check config` + `check rules` → `amtool check-config` →
  dashboard JSON validation → `helm lint` + `helm template` → hadolint →
  multi-arch (`amd64`/`arm64`) build → Trivy image scan (fails on
  HIGH/CRITICAL) → Docker Hub push (`:latest`, `:sha-<sha>`, gated on
  `DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN` secrets; warns and skips if absent).
- **cd.yml** (manual `workflow_dispatch`): SSH to the EC2 host, `git pull`,
  `docker compose up -d --build`, then curls `/healthz` and `/-/healthy`.

## Alert rules

| Alert | Condition | Severity |
|---|---|---|
| `AppDown` | scrape `up{job="demo-app"} == 0` for 1m | critical |
| `HighErrorRate` | 5xx ratio > 5% over 5m | warning |
| `HighLatencyP95` | p95 latency > 1s for 5m | warning |
| `HostHighCPU` | CPU > 85% for 5m | warning |

Wire Alertmanager's `oncall-webhook` receiver to Slack/PagerDuty by editing
`monitoring/alertmanager/alertmanager.yml`.

## Troubleshooting

- **Grafana shows "no data"**: check Prometheus targets (`:9090/targets`) —
  the app must be `UP`; `docker compose logs prometheus` shows scrape errors.
- **Port conflicts**: another service on 3000/9090/9093/8000 — stop it or
  remap ports in `docker-compose.yml`.
- **CI push skipped**: add `DOCKERHUB_USERNAME` + `DOCKERHUB_TOKEN` repo
  secrets; the job logs a warning instead of failing.
- **Terraform apply**: needs AWS credentials and an approved cost decision;
  it is intentionally manual.
