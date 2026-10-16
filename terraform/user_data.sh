#!/bin/bash
# Bootstraps the observability host: Docker + Compose plugin, then clones
# this repo and starts the stack. Grafana password comes from Terraform vars.
set -euo pipefail

dnf install -y docker git
systemctl enable --now docker
mkdir -p /usr/local/lib/docker/cli-plugins
curl -sSL -o /usr/local/lib/docker/cli-plugins/docker-compose \
  https://github.com/docker/compose/releases/download/v2.35.1/docker-compose-linux-x86_64
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

mkdir -p /opt/observability
cd /opt/observability
git clone "${repo_url}" stack
cd stack

export GRAFANA_ADMIN_PASSWORD="${grafana_admin_password}"
docker compose up -d --build
