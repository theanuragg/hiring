#!/usr/bin/env bash
set -euo pipefail

source /opt/alchemyst-hiring/may-2026/devops/quickstart/deploy/scripts/bootstrap-common.sh

require_root
install_base_packages
install_iii_engine
ensure_app_user
ensure_repo_present
ensure_runtime_dirs

apt-get install -y caddy

create_python_venv \
  "/opt/alchemyst-venvs/api-gateway" \
  "${PROJECT_ROOT}/app/api-gateway/requirements.txt"

install_executable \
  "${PROJECT_ROOT}/deploy/scripts/run-api-gateway.sh" \
  /usr/local/bin/run-api-gateway.sh

install_systemd_unit \
  "${PROJECT_ROOT}/deploy/systemd/iii-engine.service" \
  iii-engine.service
install_systemd_unit \
  "${PROJECT_ROOT}/deploy/systemd/alchemyst-api.service" \
  alchemyst-api.service

install -D -m 0644 "${PROJECT_ROOT}/deploy/iii/engine-config.yaml" /etc/iii/config.yaml
install -D -m 0644 "${PROJECT_ROOT}/deploy/caddy/Caddyfile" /etc/caddy/Caddyfile

systemctl daemon-reload
systemctl enable --now iii-engine.service
systemctl enable --now alchemyst-api.service
systemctl enable --now caddy.service
