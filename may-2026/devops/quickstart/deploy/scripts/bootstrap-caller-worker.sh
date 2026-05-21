#!/usr/bin/env bash
set -euo pipefail

source /opt/alchemyst-hiring/may-2026/devops/quickstart/deploy/scripts/bootstrap-common.sh

require_root
install_base_packages
install_nodejs
ensure_app_user
ensure_repo_present
ensure_runtime_dirs

cd "${PROJECT_ROOT}/workers/caller-worker"
npm ci
npm run build

install_executable \
  "${PROJECT_ROOT}/deploy/scripts/run-caller-worker.sh" \
  /usr/local/bin/run-caller-worker.sh
install_systemd_unit \
  "${PROJECT_ROOT}/deploy/systemd/alchemyst-caller-worker.service" \
  alchemyst-caller-worker.service

systemctl daemon-reload
systemctl enable --now alchemyst-caller-worker.service
