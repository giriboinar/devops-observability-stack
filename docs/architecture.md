# Architecture

## What this is

A production-style observability stack for a small instrumented API:

```
                +------------------+
                |   Grafana :3000  |  dashboards (provisioned)
                +--------+---------+
                         | PromQL
                +--------v---------+
                | Prometheus :9090 |  scrape 15s, 7d retention
                +--+-----+-----+---+
                   |     |     |
        /metrics   |     |     | node metrics
    +--------------v+ +--v----------+
    |  demo-app     | | node-exporter|
    |  :8000        | | :9100        |
    +---------------+ +--------------+
            |
   alerts --+--> Alertmanager :9093 -- (webhook placeholder) --> on-call
```

## Components

| Component | Image (pinned, verified) | Role |
|---|---|---|
| demo-app | built from `Dockerfile` | FastAPI API exposing RED metrics on `/metrics` |
| Prometheus | `prom/prometheus:v3.4.1` | Scrapes app + node-exporter, evaluates `alerts.yml` |
| Alertmanager | `prom/alertmanager:v0.28.1` | Deduplicates/groups/routes alerts, webhook receiver placeholder |
| Grafana | `grafana/grafana:12.1.0` | Provisioned Prometheus datasource + "demo-app overview" dashboard |
| node-exporter | `prom/node-exporter:v1.9.1` | Host CPU/memory/disk metrics, feeds `HostHighCPU` alert |

## Three ways to run

1. **Docker Compose** (`docker-compose.yml`) — one host, fastest for demos.
2. **Kubernetes** (`helm/observability-stack/`) — same components as K8s
   Deployments/Services/ConfigMaps, security-hardened pods
   (non-root, dropped capabilities, seccomp, resource limits).
3. **AWS** (`terraform/`) — Free Tier `t3.micro` in the default VPC whose
   user-data installs Docker and starts the Compose stack. Manual `apply`
   only (cost rule); SSH/Grafana/Prometheus restricted to your CIDR.

## Alert flow

Prometheus evaluates `alerts.yml` every 15s → firing alerts go to
Alertmanager → grouped by `alertname`, critical alerts also routed to the
`oncall-webhook` receiver (replace the placeholder URL with Slack/PagerDuty).

## CI/CD

`ci.yml`: pytest → compose config validation → `promtool check config/rules`
→ `amtool check-config` → dashboard JSON validation → `helm lint` +
`helm template` → hadolint → multi-arch build → Trivy (fail HIGH/CRITICAL)
→ Docker Hub push (gated on `DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN` secrets;
skips with a warning when absent). `cd.yml`: manual `workflow_dispatch`
redeploys the Compose stack on EC2 over SSH + smoke-checks the endpoints.
